use crate::{
    constants::{
        AMOUNT_KEY, AMOUNT_KEY_LENGTH, CURRENCY_CODE_KEY, CURRENCY_CODE_KEY_LENGTH,
        CURRENCY_CODE_VALUE_LENGTH, CREDITOR_ACCOUNT_KEY, INITIATION_KEY, INSTRUCTED_AMOUNT_KEY,
        MAX_AMOUNT_VALUE_LENGTH, PAYLOAD_DATA_KEY, PAYMENT_ID_KEY, PAYMENT_ID_KEY_LENGTH,
        PAYMENT_ID_LENGTH, SORT_CODE_KEY, SORT_CODE_KEY_LENGTH, SORT_CODE_VALUE_LENGTH,
    },
    io::{OpenbankingVerifierParams, OpenbankingVerifierReturn},
};
use bignum::{params::BigNumParams, RuntimeBigNum};
use json_parser::JSON;
use rsa_pss::rsa::verify_sha256_pss;
use zkemail::partial_hash::partial_sha256_var_end;

/**
 * Verifies a Openbanking payment
 * 
 * @param params -
 *        signature_limbs - signature to verify payment in limb format
 *        modulus_limbs - modulus of pubkey used to verify payment signature in limb format
 *        redc_limbs - reduction params of pubkey used to verify payment signature in limb format
 *        partial_hash_start - partial hash of the payment payload
 *        header_delimiter_index - index of "." within the payload so we know where to extract payment data
 *        payload - string where base64 header of payment JWT is concatenated with payment JSON data
 *     
 * @return - sort code, currency code, amount, and payment id from Openbanking payment
 */
pub fn verify_openbanking_payment(params: OpenbankingVerifierParams) -> OpenbankingVerifierReturn {
    let OpenbankingVerifierParams {
    signature_limbs,
    modulus_limbs,
    redc_limbs,
    partial_hash_start,
    header_delimiter_index,
    payload: payload_immut,} = params;

    // bit hacky but this lets us work around problem of passing mutable reference in struct.
    // Compiler optimizes this out
    let mut payload = payload_immut;

    // calculate length of payload already hashed by finding next lowest value divisible by 64 from delimiter index
    let partial_hash_start_preimage_length = header_delimiter_index - (header_delimiter_index % 64);

    let has_multiplicative_inverse = false;
    let params: BigNumParams<18, 2048> =
        BigNumParams::new(has_multiplicative_inverse, modulus_limbs, redc_limbs);

    let signature: RuntimeBigNum<18, 2048> = RuntimeBigNum::from_array(params, signature_limbs);

    // get complete hash of JWT by taking partial hash start and hashing the rest of the payload
    let hash: [u8; 32] = partial_sha256_var_end(
        partial_hash_start,
        payload.storage,
        payload.len() as u64,
        payload.len() as u64 + partial_hash_start_preimage_length as u64,
    );

    // verify signature over payload
    assert(verify_sha256_pss(hash, signature, 2048));

    // calculate remaning chars up to header / payload delimiter (".") that were not in the initial hash
    let carry_over_end_index = header_delimiter_index - partial_hash_start_preimage_length as u32;

    // if carry over is not 0 then set first index to whitespace (32)
    let mut byte = payload.get_unchecked(0);
    if carry_over_end_index != 0 {
        byte = 32;
    }
    payload.set(0, byte);

    // set values prior and up to delimiter to whitespace so JSON parser does not get angry
    for i in 1..64 {
        let mut index = i;
        if i > carry_over_end_index {
            index = carry_over_end_index;
        }
        payload.set(index, 32);
    }

    // init JSON. Note: Parameters may need to be adjusted depending on payload variability
    let json: JSON<1024, 34, 106, 29, 2> = JSON::parse_json(payload.storage);

    // parse through nested JSON to extract values
    let data_obj = json.get_object(PAYLOAD_DATA_KEY).unwrap();
    let initiation_obj = data_obj.get_object(INITIATION_KEY).unwrap();
    let creditor_acc_obj = initiation_obj.get_object(CREDITOR_ACCOUNT_KEY).unwrap();

    // extract payment id
    let payment_id_result =
        data_obj.get_string_unchecked::<PAYMENT_ID_KEY_LENGTH, PAYMENT_ID_LENGTH>(PAYMENT_ID_KEY);

    // extract sort code
    let sort_code_result = creditor_acc_obj
        .get_string_unchecked::<SORT_CODE_KEY_LENGTH, SORT_CODE_VALUE_LENGTH>(SORT_CODE_KEY);

    let instructed_amt_obj = initiation_obj.get_object(INSTRUCTED_AMOUNT_KEY).unwrap();
    // extract amount
    let amount_result = instructed_amt_obj
        .get_string_unchecked::<AMOUNT_KEY_LENGTH, MAX_AMOUNT_VALUE_LENGTH>(AMOUNT_KEY);

    // extract currency code
    let currency_code_result = instructed_amt_obj
        .get_string_unchecked::<CURRENCY_CODE_KEY_LENGTH, CURRENCY_CODE_VALUE_LENGTH>(
            CURRENCY_CODE_KEY,
        );


    OpenbankingVerifierReturn {
        amount: amount_result,
        currency_code: currency_code_result.storage,
        payment_id: payment_id_result.storage,
        sort_code: sort_code_result.storage,
    }
}
