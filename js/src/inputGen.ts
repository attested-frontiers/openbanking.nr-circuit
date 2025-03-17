import * as NoirBignum from '@mach-34/noir-bignum-paramgen';
import { KeyObject } from 'crypto';
import { partialSha } from '@zk-email/helpers';

import { InputValue } from '@noir-lang/noirc_abi';
import { MAX_PAYLOAD_SIZE } from './constants';
import {
  OpenBankingDomesticCircuitInputs,
  OpenBankingDomesticCircuitOutputsRaw,
  OpenBankingDomesticContractInputs,
} from './types';
import { bytesToBigInt, base64UrlToBytes, toBoundedVec, u8ToU32 } from './utils';

/**
 * Takes a pubkey in KeyObject format and transforms it to a Noir friendly format
 * 
 * @param pubkey - pubkey as KeyObject
 * @returns - pubkey as modulus limbs and reduction limbs
 */
export function generatePubkeyParams(pubkey: KeyObject): {
  modulus_limbs: string[]
  redc_limbs: string[]
} {
  // todo: stronger type check key input
  const jwk = pubkey.export({ format: 'jwk' });
  if (!jwk.n) throw new Error('Public key does not contain modulus');
  if (!pubkey.asymmetricKeyDetails?.modulusLength) throw new Error('Public key does not contain modulus length');
  const modulusLength = pubkey.asymmetricKeyDetails.modulusLength;
  const modulus = bytesToBigInt(base64UrlToBytes(jwk.n));
  return {
    modulus_limbs: NoirBignum.bnToLimbStrArray(modulus, modulusLength),
    redc_limbs: NoirBignum.bnToRedcLimbStrArray(modulus, modulusLength),
  };
}

/**
 * Transforms parameters of a valid Openbanking payment into inputs for the Openbanking.nr verifier circuit
 * 
 * @param payload - concatenation of the base64 encoded JWT header and the payment payload used to verify the signature
 * @param signature - signature over Openbanking payment
 * @param publicKey - valid pubkey used to verify Openbanking payment
 * @returns - noir inputs to be fed into Openbanking.nr verifier circuit
 */
export function generateNoirInputs(
  payload: string,
  signature: string,
  publicKey: KeyObject
): OpenBankingDomesticCircuitInputs {
  const { modulus_limbs, redc_limbs } = generatePubkeyParams(publicKey);
  const signature_limbs = NoirBignum.bnToLimbStrArray(signature);

  // extract payload data
  const encoder = new TextEncoder();

  const headerDelimiterIndex = payload.indexOf('.');
  // calculate value below or up to delimiter index that is divisible by block size
  const hashToIndex = headerDelimiterIndex - (headerDelimiterIndex % 64);

  const payloadVec = toBoundedVec(
    encoder.encode(payload.slice(hashToIndex)),
    MAX_PAYLOAD_SIZE,
    32
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
  };
}

/**
 * Generates inputs for Openbanking.nr claim_payment structure
 * 
 * @param payload - concatenation of the base64 encoded JWT header and the payment payload used to verify the signature
 * @param signature - signature over Openbanking payment
 * @param modulus_limbs - modulus limbs of the pubkey used to verify the Openbanking payment
 * @param redc_limbs - reduction limbs of the pubkey used to verify the Openbanking payment
 * @returns - smart contract inputs for claim payment in Aztec smart contract
 */
export function generateAztecInputs(
  payload: string,
  signature: string,
  modulus_limbs: string[],
  redc_limbs: string[]
): OpenBankingDomesticContractInputs {
  const signature_limbs = NoirBignum.bnToLimbStrArray(signature);

  // extract payload data
  const encoder = new TextEncoder();

  const headerDelimiterIndex = payload.indexOf('.');
  // calculate value below or up to delimiter index that is divisible by block size
  const hashToIndex = headerDelimiterIndex - (headerDelimiterIndex % 64);

  const payloadVec = toBoundedVec(
    encoder.encode(payload.slice(hashToIndex)),
    MAX_PAYLOAD_SIZE,
    32
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
    payload: payloadVec.storage,
    payload_length: payloadVec.len,
  };
}

/**
 * Decodes outputs from Openbanking.nr payment verifier circuit
 * 
 * @param outputs - outputs Openbanking.nr verifier circuit
 * @returns - decoded Openbanking.nr verifier circuit outputs
 */
export function decodeNoirOutputs(outputs: InputValue) {
  const outputRaw = outputs as OpenBankingDomesticCircuitOutputsRaw;
  const amountRaw = outputRaw.amount.storage.slice(
    0,
    parseInt(outputRaw.amount.len as string, 16)
  ) as string[];
  const amount = Number(
    Buffer.from(amountRaw.map((b) => parseInt(b))).toString('utf-8')
  );
  const currencyCode = Buffer.from(
    outputRaw.currency_code.map((b) => parseInt(b))
  ).toString('utf-8');
  const paymentId = Buffer.from(
    outputRaw.payment_id.map((b) => parseInt(b))
  ).toString('utf-8');
  const sortCode = Buffer.from(
    outputRaw.sort_code.map((b) => parseInt(b))
  ).toString('utf-8');
  return { amount, currencyCode, paymentId, sortCode };
}
