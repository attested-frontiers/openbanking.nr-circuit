const circuit = require('../../target/jwt_rsa_pss_example.json');
const fs = require('fs');
const NoirBignum = require('@mach-34/noir-bignum-paramgen');
const { Noir } = require('@noir-lang/noir_js');
const { X509Certificate } = require('crypto');
const { partialSha } = require('@zk-email/helpers');

// constants
const MAX_AMOUNT_LENGTH = 10;
const MAX_JWT_SIZE = 1536;
const MAX_PAYLOAD_SIZE = 1024;

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

async function generatePubkeyParams(pubkey) {
  const modulus = bytesToBigInt(base64UrlToBytes(pubkey.n));
  return {
    modulus_limbs: NoirBignum.bnToLimbStrArray(modulus),
    redc_limbs: NoirBignum.bnToRedcLimbStrArray(modulus),
  };
}

async function generateNoirInputs(payload, signature, publicKey) {
  const { modulus_limbs, redc_limbs } = await generatePubkeyParams(
    publicKey.export({ format: 'jwk' })
  );
  const signature_limbs = NoirBignum.bnToLimbStrArray(signature);

  // extract payload data
  const encoder = new TextEncoder();
  const dataBuffer = encoder.encode(payload);

  const headerDelimiterIndex = payload.indexOf('.');
  // calculate value below or up to delimiter index that is divisible by block size
  const hashToIndex = headerDelimiterIndex - (headerDelimiterIndex % 64);

  const payloadVec = toBoundedVec(
    encoder.encode(payload.slice(hashToIndex)),
    MAX_PAYLOAD_SIZE,
    32
  );

  // parse out nested JSON values
  const payloadData = payload.slice(headerDelimiterIndex + 1);
  const payloadParsed = JSON.parse(payloadData);

  const amount = payloadParsed.Data.Initiation.InstructedAmount.Amount;
  const amount_value = toBoundedVec(encoder.encode(amount), MAX_AMOUNT_LENGTH);
  const currency_code = Array.from(
    encoder.encode(payloadParsed.Data.Initiation.InstructedAmount.Currency)
  );
  const sort_code = Array.from(
    encoder.encode(payloadParsed.Data.Initiation.DebtorAccount.Identification)
  );

  // compute partial hash of header
  const partialHashStart = partialSha(
    encoder.encode(payload.slice(0, hashToIndex)),
    hashToIndex
  );

  return {
    signature_limbs,
    modulus_limbs,
    redc_limbs,
    partial_hash_start: Array.from(u8ToU32(partialHashStart)),
    header_delimiter_index: headerDelimiterIndex,
    payload: payloadVec,
    amount: amount_value,
    currency_code,
    sort_code,
  };
}

function toBoundedVec(data, maxLength, fillVal) {
  let length = maxLength === undefined ? MAX_JWT_SIZE : maxLength;
  if (data.length > length) {
    throw new Error(`Data exceeds maximum length of ${length} bytes`);
  }
  data = Array.from(data);
  const storage = data
    .concat(Array(length - data.length).fill(fillVal ?? 0))
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

const u8ToU32 = (input) => {
  const out = new Uint32Array(input.length / 4);
  for (let i = 0; i < out.length; i++) {
    out[i] =
      (input[i * 4 + 0] << 24) |
      (input[i * 4 + 1] << 16) |
      (input[i * 4 + 2] << 8) |
      (input[i * 4 + 3] << 0);
  }
  return out;
};

const main = async () => {
  const payload = fs.readFileSync('./revolut_payload.txt', 'utf8');
  const signature =
    '3e42c30cab535ed5a20dcac4d405004b5098451c72a80b4460b4e3e9a4bc89f131fa6078c1f7de1d740bfd8216e0ea8b67e5d78eaa7897d02902d73c50d3d0e7bbeb4e1b4b6b4d0281bcfb0e029c44f3ea90363e4e1d7ec591e09fc2bdd832428396b054f4f89336df49c01a88bb7e5b5015e706cd179467bf9794a79474884e799fb388050a7fdcaa074225bdc1b856048640e4fb7955a06675649acd89b049b603c0dc32dc5f37796453602f36cc982f86257055162457db6aec9377e7e9fdcb31e4ebce5d6e445c722f0e6a20936bda5c83481b12013078c0cc72551373586dc69db541d729b8d02521a26bb4f42068764438443e9c9164dca039b0fb1176';
  const cert = fs.readFileSync('./revolut.cert', 'utf8');
  const { publicKey } = new X509Certificate(cert);
  const inputs = await generateNoirInputs(payload, signature, publicKey);
  const noir = new Noir(circuit);
  const { witness } = await noir.execute(inputs);
  console.log('Witness: ', witness);
};

main();
