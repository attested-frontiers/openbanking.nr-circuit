use crate::constants::{RevolutVerifierParams, RevolutVerifierReturn};
use bignum::{params::BigNumParams, RuntimeBigNum};
use json_parser::JSON;
use rsa_pss::rsa::verify_sha256_pss;
use zkemail::partial_hash::{partial_sha256_var_end, partial_sha256_var_start};

pub global MAX_JWT_SIZE: u32 = 1536;
pub global MAX_PAYLOAD_LENGTH: u32 = 1024;

pub global CURRENCY_CODE_VALUE_LENGTH: u32 = 3;
pub global CURRENCY_CODE_KEY_LENGTH: u32 = 8;
pub global SORT_CODE_KEY_LENGTH: u32 = 14;
pub global SORT_CODE_VALUE_LENGTH: u32 = 14;
pub global AMOUNT_KEY_LENGTH: u32 = 6;
pub global MAX_AMOUNT_VALUE_LENGTH: u32 = 10;

pub global AMOUNT_KEY: [u8; AMOUNT_KEY_LENGTH] = comptime { "Amount".as_bytes() };
pub global CURRENCY_CODE_KEY: [u8; CURRENCY_CODE_KEY_LENGTH] = comptime { "Currency".as_bytes() };
pub global DEBTOR_ACCOUNT_KEY: [u8; 13] = comptime { "DebtorAccount".as_bytes() };
pub global INITIATION_KEY: [u8; 10] = comptime { "Initiation".as_bytes() };
pub global INSTRUCTED_AMOUNT_KEY: [u8; 16] = comptime { "InstructedAmount".as_bytes() };
pub global PAYLOAD_DATA_KEY: [u8; 4] = comptime { "Data".as_bytes() };
pub global SORT_CODE_KEY: [u8; SORT_CODE_KEY_LENGTH] = comptime { "Identification".as_bytes() };

fn verify_revolut(params: RevolutVerifierParams) -> RevolutVerifierReturn {
    let RevolutVerifierParams {
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
    let debtor_acc_obj = initiation_obj.get_object(DEBTOR_ACCOUNT_KEY).unwrap();

    // extract sort code
    let sort_code_result = debtor_acc_obj
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

    RevolutVerifierReturn {
        amount: amount_result,
        currency_code: currency_code_result.storage,
        sort_code: sort_code_result.storage,
    }
}
