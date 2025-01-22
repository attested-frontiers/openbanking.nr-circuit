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

const escapeNestedJSON = (input) => {
  if (typeof input === 'string') {
    // Escape quotes in strings
    return input.replace(/\"/g, '\\"');
  } else if (Array.isArray(input)) {
    // Recursively escape each element in the array
    return input.map(escapeNestedJSON);
  } else if (typeof input === 'object' && input !== null) {
    // Recursively escape keys and values in the object
    const escapedObject = {};
    for (const [key, value] of Object.entries(input)) {
      const escapedKey = escapeNestedJSON(key);
      const escapedValue = escapeNestedJSON(value);
      escapedObject[escapedKey] = escapedValue;
    }
    return escapedObject;
  } else {
    // Return non-string, non-object types as is (e.g., numbers, booleans, null)
    return input;
  }
};

// console.log(generateJWSSignature(paymentPayload));

async function main() {
  const stringified = `eyJraWQiOiJvSjQwLUcxVklxbUU2eUhuYnA4S1E1Qmk2bXciLCJhbGciOiJQUzI1NiIsImNyaXQiOlsiYjY0IiwiaHR0cDovL29wZW5iYW5raW5nLm9yZy51ay9pYXQiLCJodHRwOi8vb3BlbmJhbmtpbmcub3JnLnVrL2lzcyIsImh0dHA6Ly9vcGVuYmFua2luZy5vcmcudWsvdGFuIl0sImI2NCI6ZmFsc2UsImh0dHA6Ly9vcGVuYmFua2luZy5vcmcudWsvdGFuIjoib3BlbmJhbmtpbmcub3JnLnVrIiwiaHR0cDovL29wZW5iYW5raW5nLm9yZy51ay9pc3MiOiIwMDE1ODAwMDAxMDNVQXZBQU0iLCJodHRwOi8vb3BlbmJhbmtpbmcub3JnLnVrL2lhdCI6MTczNTgyNTE5OX0.{"Data":{"DomesticPaymentId":"6776972f-e9af-ad6a-8cdd-ff2099bd2475","Status":"Pending","StatusUpdateDateTime":"2025-01-02T13:39:59.455059Z","CreationDateTime":"2025-01-02T13:39:59.455059Z","ConsentId":"6d2e1641-e486-4a3a-936b-065628f2a926","Initiation":{"RemittanceInformation":{"Unstructured":"Shipment fee"},"DebtorAccount":{"SchemeName":"UK.OBIE.SortCodeAccountNumber","Identification":"04290953215338","Name":"Acme Corporation"},"EndToEndIdentification":"E2E123","InstructionIdentification":"ID412","CreditorAccount":{"Name":"Receiver Co.","SchemeName":"UK.OBIE.SortCodeAccountNumber","Identification":"11223321325698"},"InstructedAmount":{"Amount":"1.00","Currency":"GBP"}}},"Links":{"Self":"https://sandbox-oba.revolut.com/domestic-payments/6776972f-e9af-ad6a-8cdd-ff2099bd2475"},"Meta":{"TotalPages":1}}`;
  // add escape characters
  const headerEndIndex = stringified.indexOf('.');
  console.log(
    Buffer.from([
      123, 34, 68, 97, 116, 97, 34, 58, 123, 34, 68, 111, 109, 101, 115, 116,
      105, 99, 80, 97, 121, 109, 101, 110, 116, 73, 100, 34, 58, 34, 54, 55, 55,
      54, 57, 55, 50, 102, 45, 101, 57, 97, 102, 45, 97, 100, 54, 97, 45, 56,
      99, 100, 100, 45, 102, 102, 50, 48, 57, 57, 98, 100, 50, 52, 55, 53, 34,
      44, 34, 83, 116, 97, 116, 117, 115, 34, 58, 34, 80, 101, 110, 100, 105,
      110, 103, 34, 44, 34, 83, 116, 97, 116, 117, 115, 85, 112, 100, 97, 116,
      101, 68, 97, 116, 101, 84, 105, 109, 101, 34, 58, 34, 50, 48, 50, 53, 45,
      48, 49, 45, 48, 50, 84, 49, 51, 58, 51, 57, 58, 53, 57, 46, 52, 53, 53,
      48, 53, 57, 90, 34, 44, 34, 67, 114, 101, 97, 116, 105, 111, 110, 68, 97,
      116, 101, 84, 105, 109, 101, 34, 58, 34, 50, 48, 50, 53, 45, 48, 49, 45,
      48, 50, 84, 49, 51, 58, 51, 57, 58, 53, 57, 46, 52, 53, 53, 48, 53, 57,
      90, 34, 44, 34, 67, 111, 110, 115, 101, 110, 116, 73, 100, 34, 58, 34, 54,
      100, 50, 101, 49, 54, 52, 49, 45, 101, 52, 56, 54, 45, 52, 97, 51, 97, 45,
      57, 51, 54, 98, 45, 48, 54, 53, 54, 50, 56, 102, 50, 97, 57, 50, 54, 34,
      44, 34, 73, 110, 105, 116, 105, 97, 116, 105, 111, 110, 34, 58, 123, 34,
      82, 101, 109, 105, 116, 116, 97, 110, 99, 101, 73, 110, 102, 111, 114,
      109, 97, 116, 105, 111, 110, 34, 58, 123, 34, 85, 110, 115, 116, 114, 117,
      99, 116, 117, 114, 101, 100, 34, 58, 34, 83, 104, 105, 112, 109, 101, 110,
      116, 32, 102, 101, 101, 34, 125, 44, 34, 68, 101, 98, 116, 111, 114, 65,
      99, 99, 111, 117, 110, 116, 34, 58, 123, 34, 83, 99, 104, 101, 109, 101,
      78, 97, 109, 101, 34, 58, 34, 85, 75, 46, 79, 66, 73, 69, 46, 83, 111,
      114, 116, 67, 111, 100, 101, 65, 99, 99, 111, 117, 110, 116, 78, 117, 109,
      98, 101, 114, 34, 44, 34, 73, 100, 101, 110, 116, 105, 102, 105, 99, 97,
      116, 105, 111, 110, 34, 58, 34, 48, 52, 50, 57, 48, 57, 53, 51, 50, 49,
      53, 51, 51, 56, 34, 44, 34, 78, 97, 109, 101, 34, 58, 34, 65, 99, 109,
      101, 32, 67, 111, 114, 112, 111, 114, 97, 116, 105, 111, 110, 34, 125, 44,
      34, 69, 110, 100, 84, 111, 69, 110, 100, 73, 100, 101, 110, 116, 105, 102,
      105, 99, 97, 116, 105, 111, 110, 34, 58, 34, 69, 50, 69, 49, 50, 51, 34,
      44, 34, 73, 110, 115, 116, 114, 117, 99, 116, 105, 111, 110, 73, 100, 101,
      110, 116, 105, 102, 105, 99, 97, 116, 105, 111, 110, 34, 58, 34, 73, 68,
      52, 49, 50, 34, 44, 34, 67, 114, 101, 100, 105, 116, 111, 114, 65, 99, 99,
      111, 117, 110, 116, 34, 58, 123, 34, 78, 97, 109, 101, 34, 58, 34, 82,
      101, 99, 101, 105, 118, 101, 114, 32, 67, 111, 46, 34, 44, 34, 83, 99,
      104, 101, 109, 101, 78, 97, 109, 101, 34, 58, 34, 85, 75, 46, 79, 66, 73,
      69, 46, 83, 111, 114, 116, 67, 111, 100, 101, 65, 99, 99, 111, 117, 110,
      116, 78, 117, 109, 98, 101, 114, 34, 44, 34, 73, 100, 101, 110, 116, 105,
      102, 105, 99, 97, 116, 105, 111, 110, 34, 58, 34, 49, 49, 50, 50, 51, 51,
      50, 49, 51, 50, 53, 54, 57, 56, 34, 125, 44, 34, 73, 110, 115, 116, 114,
      117, 99, 116, 101, 100, 65, 109, 111, 117, 110, 116, 34, 58, 123, 34, 65,
      109, 111, 117, 110, 116, 34, 58, 34, 49, 46, 48, 48, 34, 44, 34, 67, 117,
      114, 114, 101, 110, 99, 121, 34, 58, 34, 71, 66, 80, 34, 125, 125, 125,
      44, 34, 76, 105, 110, 107, 115, 34, 58, 123, 34, 83, 101, 108, 102, 34,
      58, 34, 104, 116, 116, 112, 115, 58, 47, 47, 115, 97, 110, 100, 98, 111,
      120, 45, 111, 98, 97, 46, 114, 101, 118, 111, 108, 117, 116, 46, 99, 111,
      109, 47, 100, 111, 109, 101, 115, 116, 105, 99, 45, 112, 97, 121, 109,
      101, 110, 116, 115, 47, 54, 55, 55, 54, 57, 55, 50, 102, 45, 101, 57, 97,
      102, 45, 97, 100, 54, 97, 45, 56, 99, 100, 100, 45, 102, 102, 50, 48, 57,
      57, 98, 100, 50, 52, 55, 53, 34, 125, 44, 34, 77, 101, 116, 97, 34, 58,
      123, 34, 84, 111, 116, 97, 108, 80, 97, 103, 101, 115, 34, 58, 49, 125,
      125, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ]).toString()
  );
  // const header = stringified.slice(0, headerEndIndex);
  // const payload = escapeNestedJSON(stringified.slice(headerEndIndex + 1));
  // const concatenated = `${header}.${payload}`;
  // const num = 897;
  // const bytes = new Uint8Array(Buffer.from(stringified));
  // const padded = new Uint8Array(1536);
  // for (let i = 0; i < bytes.length; i++) {
  //   padded[i] = bytes[i];
  // }
  // console.log('Bytes: ', JSON.stringify(Array.from(padded)));
  // const { witness, returnValue } = await execute({ jwt: inputs });
  // console.log("inp len", inputs.redc_params_limbs.length)
  // console.log("success :)")
  // const key = await newRSAKey();
  // const inputs = await generateNoirInputs(paymentPayload2, key);
  // console.log(
  //   'Inputs: ',
  //   JSON.stringify(inputs.data.map((val) => Number(val)))
  // );
  // console.log(toProverToml(inputs))
  // const { witness, returnValue } = await execute(inputs)
}

main();
