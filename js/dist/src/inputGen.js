"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generatePubkeyParams = generatePubkeyParams;
exports.generateNoirInputs = generateNoirInputs;
const NoirBignum = __importStar(require("@mach-34/noir-bignum-paramgen"));
const helpers_1 = require("@zk-email/helpers");
const constants_1 = require("./constants");
const utils_1 = require("./utils");
function generatePubkeyParams(pubkey) {
    // todo: stronger type check key input
    const jwk = pubkey.export({ format: 'jwk' });
    if (!jwk.n)
        throw new Error('Public key does not contain modulus');
    if (!pubkey.asymmetricKeyDetails?.modulusLength)
        throw new Error('Public key does not contain modulus length');
    const modulusLength = pubkey.asymmetricKeyDetails.modulusLength;
    const modulus = (0, utils_1.bytesToBigInt)((0, utils_1.base64UrlToBytes)(jwk.n));
    return {
        modulus_limbs: NoirBignum.bnToLimbStrArray(modulus, modulusLength),
        redc_limbs: NoirBignum.bnToRedcLimbStrArray(modulus, modulusLength),
    };
}
function generateNoirInputs(payload, signature, publicKey) {
    const { modulus_limbs, redc_limbs } = generatePubkeyParams(publicKey);
    const signature_limbs = NoirBignum.bnToLimbStrArray(signature);
    // extract payload data
    const encoder = new TextEncoder();
    const headerDelimiterIndex = payload.indexOf('.');
    // calculate value below or up to delimiter index that is divisible by block size
    const hashToIndex = headerDelimiterIndex - (headerDelimiterIndex % 64);
    const payloadVec = (0, utils_1.toBoundedVec)(encoder.encode(payload.slice(hashToIndex)), constants_1.MAX_PAYLOAD_SIZE, 32);
    // parse out nested JSON values
    const payloadData = payload.slice(headerDelimiterIndex + 1);
    const payloadParsed = JSON.parse(payloadData);
    const amount = payloadParsed.Data.Initiation.InstructedAmount.Amount;
    const amount_value = (0, utils_1.toBoundedVec)(encoder.encode(amount), constants_1.MAX_AMOUNT_LENGTH);
    const currency_code = Array.from(encoder.encode(payloadParsed.Data.Initiation.InstructedAmount.Currency));
    const sort_code = Array.from(encoder.encode(payloadParsed.Data.Initiation.DebtorAccount.Identification));
    // compute partial hash of header
    const partialHashStart = (0, helpers_1.partialSha)(encoder.encode(payload.slice(0, hashToIndex)), hashToIndex);
    return {
        signature_limbs,
        modulus_limbs,
        redc_limbs,
        partial_hash_start: Array.from((0, utils_1.u8ToU32)(partialHashStart)),
        header_delimiter_index: headerDelimiterIndex,
        payload: payloadVec,
        amount: amount_value,
        currency_code,
        sort_code,
    };
}
