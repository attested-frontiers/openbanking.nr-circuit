const crypto = require('crypto');
const fs = require('fs');
const { Noir } = require('@noir-lang/noir_js');
const circuit = require('../../target/jwt_test.json');
const paymentPayload = require('./data.json');
const paymentPayload2 = require('./data2.json');
const NoirBignum = require('@mach-34/noir-bignum-paramgen');
const MAX_JWT_SIZE = 1536;

/**
 * Given a claim (?) from a JWT, generate a JWS signature over the claim
 * @param {*} payload
 * @returns
 */
async function generateJWSSignature(payload, privateKey, publicKey) {
  try {
    // Base64URL encode header and payload
    const base64Data =
      typeof payload === 'string' && isBase64(payload)
        ? data
        : Buffer.from(JSON.stringify(payload)).toString('base64');

    // Convert base64 to ArrayBuffer for signing
    const encoder = new TextEncoder();
    const dataBuffer = encoder.encode(base64Data);

    const hashBuffer = await crypto.subtle.digest('SHA-256', dataBuffer);

    // If you need it as Uint8Array:
    const hashArray = new Uint8Array(hashBuffer);
    console.log('Hash', hashArray);

    // Sign the data
    const signature = await crypto.subtle.sign(
      {
        name: 'RSASSA-PKCS1-v1_5',
      },
      privateKey,
      dataBuffer
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
}

async function newRSAKey() {
  return await crypto.subtle.generateKey(
    {
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([0x01, 0x00, 0x01]), // 65537
      hash: 'SHA-256',
    },
    true, // extractable
    ['sign', 'verify']
  );
}

async function pubkeyFromKeypair(keyPair) {
  const pubkey = await crypto.subtle.exportKey('jwk', keyPair.publicKey);
  const modulus = bytesToBigInt(base64UrlToBytes(pubkey.n));
  return {
    modulus: NoirBignum.bnToLimbStrArray(modulus),
    redc: NoirBignum.bnToRedcLimbStrArray(modulus),
  };
}

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

async function generateNoirInputs(payload, keypair) {
  const { data, signature } = await generateJWSSignature(
    payload,
    keypair.privateKey,
    keypair.publicKey
  );

  const pubkey = await pubkeyFromKeypair(keypair);
  return {
    // data,
    data: data.storage,
    data_len: data.len,
    pubkey_modulus_limbs: pubkey.modulus,
    redc_params_limbs: pubkey.redc,
    signature_limbs: signature,
    // // partial_hash: ["0", "0", "0", "0", "0", "0", "0", "0"],
    // full_data_length: data.len,
    // is_partial_hash: "0"
  };
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

async function execute(inputs) {
  const noir = new Noir(circuit);
  return await noir.execute(inputs);
}

// console.log(generateJWSSignature(paymentPayload));

async function main() {
  // const stringified = `eyJraWQiOiJvSjQwLUcxVklxbUU2eUhuYnA4S1E1Qmk2bXciLCJhbGciOiJQUzI1NiIsImNyaXQiOlsiYjY0IiwiaHR0cDovL29wZW5iYW5raW5nLm9yZy51ay9pYXQiLCJodHRwOi8vb3BlbmJhbmtpbmcub3JnLnVrL2lzcyIsImh0dHA6Ly9vcGVuYmFua2luZy5vcmcudWsvdGFuIl0sImI2NCI6ZmFsc2UsImh0dHA6Ly9vcGVuYmFua2luZy5vcmcudWsvdGFuIjoib3BlbmJhbmtpbmcub3JnLnVrIiwiaHR0cDovL29wZW5iYW5raW5nLm9yZy51ay9pc3MiOiIwMDE1ODAwMDAxMDNVQXZBQU0iLCJodHRwOi8vb3BlbmJhbmtpbmcub3JnLnVrL2lhdCI6MTczNTgyNTE5OX0.{"Data":{"DomesticPaymentId":"6776972f-e9af-ad6a-8cdd-ff2099bd2475","Status":"Pending","StatusUpdateDateTime":"2025-01-02T13:39:59.455059Z","CreationDateTime":"2025-01-02T13:39:59.455059Z","ConsentId":"6d2e1641-e486-4a3a-936b-065628f2a926","Initiation":{"RemittanceInformation":{"Unstructured":"Shipment fee"},"DebtorAccount":{"SchemeName":"UK.OBIE.SortCodeAccountNumber","Identification":"04290953215338","Name":"Acme Corporation"},"EndToEndIdentification":"E2E123","InstructionIdentification":"ID412","CreditorAccount":{"Name":"Receiver Co.","SchemeName":"UK.OBIE.SortCodeAccountNumber","Identification":"11223321325698"},"InstructedAmount":{"Amount":"1.00","Currency":"GBP"}}},"Links":{"Self":"https://sandbox-oba.revolut.com/domestic-payments/6776972f-e9af-ad6a-8cdd-ff2099bd2475"},"Meta":{"TotalPages":1}}`;
  // const bytes = new Uint8Array(Buffer.from(stringified));
  // const padded = new Uint8Array(1536);
  // for (let i = 0; i < bytes.length; i++) {
  //   padded[i] = bytes[i];
  // }
  // console.log('Bytes: ', JSON.stringify(Array.from(padded)));
  // const { witness, returnValue } = await execute({ jwt: inputs });
  // console.log("inp len", inputs.redc_params_limbs.length)
  // console.log("success :)")
  const key = await newRSAKey();
  const inputs = await generateNoirInputs(paymentPayload2, key);
  console.log(
    'Inputs: ',
    JSON.stringify(inputs.data.map((val) => Number(val)))
  );
  // console.log(toProverToml(inputs))
  // const { witness, returnValue } = await execute(inputs)
}

main();
