const circuit = require('../../jwt-rsa-pss-example/target/jwt_rsa_pss_example.json');
const paymentPayload = require('./data2.json');
const NoirBignum = require('@mach-34/noir-bignum-paramgen');
const { Noir } = require('@noir-lang/noir_js');

// constants
const MAX_AMOUNT_LENGTH = 10;
const MAX_JWT_SIZE = 1536;

function base64UrlToBytes(base64Url) {
  const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
  const padding = '='.repeat((4 - (base64.length % 4)) % 4);
  const base64Padded = base64 + padding;
  return Uint8Array.from(atob(base64Padded), (c) => c.charCodeAt(0));
}

function bytesToBigInt(bytes) {
  let hex = Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
  return BigInt('0x' + hex);
}

/**
 * Given a claim (?) from a JWT, generate a JWS signature over the claim
 * @param {*} payload
 * @returns
 */
const generateJWSSignature = async (privateKey) => {
  try {
    // convert header and payload to buffer
    const encoder = new TextEncoder();
    const dataBuffer = encoder.encode(
      `${paymentPayload.Header}.${JSON.stringify(paymentPayload.Payload)}`
    );

    const hash = await crypto.subtle.digest('SHA-256', dataBuffer);

    // Sign the data
    const signature = await crypto.subtle.sign(
      {
        name: 'RSA-PSS',
        saltLength: 0,
      },
      privateKey,
      hash
    );

    // Return complete JWS
    let sig = BigInt(`0x${Buffer.from(signature).toString('hex')}`);
    return {
      data: toBoundedVec(Buffer.from(dataBuffer)),
      signature: NoirBignum.bnToLimbStrArray(sig),
    };
  } catch (error) {
    console.error('Error generating JWS signature:', error);
    throw error;
  }
};

async function pubkeyFromKeypair(publicKey) {
  const pubkey = await crypto.subtle.exportKey('jwk', publicKey);
  const modulus = bytesToBigInt(base64UrlToBytes(pubkey.n));
  return {
    modulus: NoirBignum.bnToLimbStrArray(modulus),
    redc: NoirBignum.bnToRedcLimbStrArray(modulus),
  };
}

async function generateNoirInputs(payload, keypair) {
  const { data, signature } = await generateJWSSignature(keypair.privateKey);

  const pubkey = await pubkeyFromKeypair(keypair.publicKey);
  const amount = paymentPayload.Payload.Data.Initiation.InstructedAmount.Amount;
  const amount_value = toBoundedVec(
    new Uint8Array(Buffer.from(amount)),
    MAX_AMOUNT_LENGTH
  );
  return {
    signature_limbs: signature,
    modulus_limbs: pubkey.modulus,
    redc_limbs: pubkey.redc,
    data: {
      storage: data.storage.map((val) => Number(val)),
      len: Number(data.len),
    },
    amount_value: {
      storage: amount_value.storage.map((val) => Number(val)),
      len: Number(amount_value.len),
    },
  };
}

async function newRSAKey() {
  return await crypto.subtle.generateKey(
    {
      name: 'RSA-PSS',
      modulusLength: 2048,
      publicExponent: new Uint8Array([0x01, 0x00, 0x01]), // 65537
      hash: 'SHA-256',
    },
    true, // extractable
    ['sign', 'verify']
  );
}

function toBoundedVec(data, maxLength) {
  let length = maxLength === undefined ? MAX_JWT_SIZE : maxLength;
  if (data.length > length) {
    throw new Error(`Data exceeds maximum length of ${length} bytes`);
  }
  data = Array.from(data);
  const storage = data
    .concat(Array(length - data.length).fill(0))
    .map((byte) => byte.toString());
  return { storage, len: data.length.toString() };
}

function toProverToml(inputs) {
  const lines = [];
  const structs = [];
  for (const [key, value] of Object.entries(inputs)) {
    if (Array.isArray(value)) {
      const valueStrArr = value.map((val) => `'${val}'`);
      lines.push(`${key} = [${valueStrArr.join(', ')}]`);
    } else if (typeof value === 'string') {
      lines.push(`${key} = '${value}'`);
    } else {
      let values = '';
      for (const [k, v] of Object.entries(value)) {
        if (Array.isArray(v)) {
          values = values.concat(
            `${k} = [${v.map((val) => `'${val}'`).join(', ')}]\n`
          );
        } else {
          values = values.concat(`${k} = '${v}'\n`);
        }
      }
      structs.push(`[${key}]\n${values}`);
    }
  }
  return lines.concat(structs).join('\n');
}

const main = async () => {
  // generate RSA keypair
  const rsa = await newRSAKey();
  const inputs = await generateNoirInputs(paymentPayload, rsa);
  const noir = new Noir(circuit);
  await noir.execute(inputs);
};

main();
