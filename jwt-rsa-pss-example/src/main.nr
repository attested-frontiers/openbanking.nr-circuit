use bignum::{params::BigNumParams, RuntimeBigNum};
use json_parser::JSON;
use rsa_pss::rsa::verify_sha256_pss;

pub global MAX_JWT_SIZE: u32 = 1536;
pub global MAX_PAYLOAD_LENGTH: u32 = 1024;
pub global MAX_HEADER_LENGTH: u32 = MAX_JWT_SIZE - MAX_PAYLOAD_LENGTH;

pub global JSON_PAYLOAD_LENGTH: u32 = 810;

pub global AMOUNT_KEY: [u8; 6] = comptime { "Amount".as_bytes() };
pub global CONSENT_ID_LENGTH: u32 = 36;
pub global CONSENT_ID_KEY: [u8; 9] = comptime { "ConsentId".as_bytes() };
pub global INITIATION_KEY: [u8; 10] = comptime { "Initiation".as_bytes() };
pub global INSTRUCTED_AMOUNT_KEY: [u8; 16] = comptime { "InstructedAmount".as_bytes() };
pub global MAX_AMOUNT_VALUE_LENGTH: u32 = 10;
pub global MAX_UNSTRUCTURED_LENGTH: u32 = 12;
pub global PAYLOAD_DATA_KEY: [u8; 4] = comptime { "Data".as_bytes() };
pub global REMITTANCE_KEY: [u8; 21] = comptime { "RemittanceInformation".as_bytes() };
pub global UNSTRUCTURED_KEY: [u8; 12] = comptime { "Unstructured".as_bytes() };

fn main(
    signature_limbs: [Field; 18],
    modulus_limbs: [Field; 18],
    redc_limbs: [Field; 18],
    data: BoundedVec<u8, MAX_JWT_SIZE>,
    consent_id_value: [u8; CONSENT_ID_LENGTH],
    amount_value: BoundedVec<u8, MAX_AMOUNT_VALUE_LENGTH>,
    unstructured_value: BoundedVec<u8, MAX_UNSTRUCTURED_LENGTH>,
) {
    let has_multiplicative_inverse = false;
    let params: BigNumParams<18, 2048> =
        BigNumParams::new(has_multiplicative_inverse, modulus_limbs, redc_limbs);

    let signature: RuntimeBigNum<18, 2048> = RuntimeBigNum::from_array(params, signature_limbs);

    // hash jwt
    let hash: [u8; 32] = dep::std::hash::sha256_var(data.storage, data.len as u64);

    // verify signature over payload
    assert(verify_sha256_pss(hash, signature, 2048));

    let mut json_payload_bytes: [u8; MAX_PAYLOAD_LENGTH] = [32; MAX_PAYLOAD_LENGTH];

    // let mut header_delimiter_index = 0;
    // for i in 0..MAX_HEADER_LENGTH {
    //     let value = data.get(i);
    //     if (header_delimiter_index == 0) & (value == 0x2E) {
    //         header_delimiter_index = i;
    //     }
    // }

    // for i in 0..MAX_JWT_SIZE {
    //     let index = header_delimiter_index - i - 1;
    //     let value = data.get(i);
    //     if(i > header_delimiter_index) & (i < data.len) {
    //         json_payload_bytes[index] = value;
    //     }
    // }

    let mut header_delimiter_index = 0;
    for i in 0..MAX_HEADER_LENGTH {
        let value = data.get(i);
        if (header_delimiter_index == 0) & (value == 0x2E) {
            header_delimiter_index = i;
        }
    }

    for i in 1..MAX_JWT_SIZE {
        let mut index = 0;
        let value = data.get_unchecked(i);
        if(i > header_delimiter_index) & (i < data.len) {
            index = header_delimiter_index - i - 1;
        }
        json_payload_bytes[index] = value;
    }
    json_payload_bytes[header_delimiter_index - 1] = data.get(0);

    // assign first index of json payload bytes to "{" as it is skipped in loop
    // json_payload_bytes[0] = 123;
    // maxmimum payload length isn't reached assign to 32 (whitespace) to end of array to make JSON parse happy
    // if (json_payload_bytes[MAX_PAYLOAD_LENGTH - 2] == 32) & (json_payload_bytes[MAX_PAYLOAD_LENGTH - 1] != 32) {
    //     json_payload_bytes[MAX_PAYLOAD_LENGTH - 1] = 32;
    // }

    // dep::std::print(json_payload_bytes);

    // init JSON
    // let json: JSON<1024, 37, 128, 65, 2> = JSON::parse_json(json_payload_bytes);

    // let mut nested_json = json.get_object(PAYLOAD_DATA_KEY).unwrap();
    // // extract consent id;
    // let consent_id_result = nested_json.get_string_unchecked(CONSENT_ID_KEY);
    // assert(consent_id_result.storage == consent_id_value);
    // // extract amount
    // let mut nested_json2 = nested_json.get_object(INITIATION_KEY).unwrap();
    // let mut nested_json_3 = nested_json2.get_object(INSTRUCTED_AMOUNT_KEY).unwrap();
    // let amount_result = nested_json_3.get_string_unchecked(AMOUNT_KEY);
    // assert(amount_result.storage == amount_value.storage);

    // let mut nested_json_4 = nested_json2.get_object(REMITTANCE_KEY).unwrap();
    // let unstructured_result = nested_json_4.get_string_unchecked(UNSTRUCTURED_KEY);
    // assert(unstructured_result.storage == unstructured_value.storage);
}

#[test]
fn test_main() {
    // pubkey from revolut (also extracted from verifyRevolutJwt.js)
    let modulus_limbs = [
        0x83e879145bffccbe4d783abeca8999,
        0xb7d9868f5b915b43f6c6a8193a1a4f,
        0x67f95badedef107f0998ab3d52961e,
        0x7dcc9780ac8d71c6b49bbfeca25f0,
        0xf9fdced289a3d4f62830681be65b50,
        0x986aa8fe98888e9f609af97515b036,
        0xd494bc65f4608849a6ed8cf5cb82ed,
        0x18ca508b8353e676387d22667e4adb,
        0x9d3fcb816b4763099ccbb7416a7ad,
        0xcfd89fee1ffcfa5f2243c92e3908b7,
        0xcaf320fbb34158238b41042f9c6386,
        0xb3df0cd5dee269ecec61b342880c59,
        0x2134236dc67b59df001cac48181625,
        0x536d424ce3dcaf2b3c15eba3ceb98,
        0x7c6532647de2f025c4245c4a816ea9,
        0x1ca6b6ac38706f61dd460c53293c88,
        0x812b9256f612815edb22ec614a6c89,
        0xc9,
    ];

    let redc_limbs = [
        0x9ec08341171d384b92ed35848dac43,
        0xaa5e7059598102ad1d99f33e533781,
        0x894978a6e54a780efd6c579b74dd3f,
        0x9531219036eb346dc4d2f142d9aeb3,
        0x2d67220edac65500daea360896b937,
        0x72393de3ce76a185b8d5fe4efeb301,
        0x2e5a676dc2d3d971ead0a1a8127ff1,
        0xbb92e11f4b88fb1f478a8e5fcc8a63,
        0x978205931de77dc276cbffcfa9ab06,
        0x3f0074f27a70de9b87b38923c5d26f,
        0x315d3964500ad7da70267bebb13aed,
        0xee04558c06aced97c3375cb93ae624,
        0xcaf9c90ec5317baf27dabd3f3a6018,
        0x453a832dd0cf10c2e7669123ffdabe,
        0xc6c46372e3eda40f2582e2e9902867,
        0xcdb6b9ecb85a01524cbe4cee82a2c2,
        0xbbaa5920d526e092f29b41b1c629e1,
        0x1453,
    ];

    // signature from verifyRevolutJwt.js
    let signature_limbs = [
        0x2e3f7f3a3b7d89cbf680adcee4f039,
        0xcca286445a216e1c110416099710f3,
        0x0684d04d7773fbff2223360e314f47,
        0x1342e7d3f7cadd18ba5f0ed57b1e54,
        0xe5347fc80630780900cffe3d20cb7d,
        0xda578cadd719f2a38f505d54c46203,
        0x4a729fdd97383a0e32b5e8f671c833,
        0x810ea2ce9ace9bd072bd3b221c9b62,
        0xc565d6bff72c8501a729ecab2aee3b,
        0xe042b627c4e6b4cc6ab4ca0ababaaa,
        0x8e707750c71a4f9f0b9d9389b61826,
        0x850297f956c58dafb6bf4f7bb049fa,
        0x32c51e7454edae060725c509d9a48c,
        0xbe2f1df6227e67dc61e6ab82bc501f,
        0xea17c90cc7053bbb94ddfac6b1a405,
        0x6c6eaada9c24dfa1a476c3718f6735,
        0x0134b376c64ba2a79a086061573792,
        0x22,
    ];

    let jwt = comptime { "eyJraWQiOiJvSjQwLUcxVklxbUU2eUhuYnA4S1E1Qmk2bXciLCJhbGciOiJQUzI1NiIsImNyaXQiOlsiYjY0IiwiaHR0cDovL29wZW5iYW5raW5nLm9yZy51ay9pYXQiLCJodHRwOi8vb3BlbmJhbmtpbmcub3JnLnVrL2lzcyIsImh0dHA6Ly9vcGVuYmFua2luZy5vcmcudWsvdGFuIl0sImI2NCI6ZmFsc2UsImh0dHA6Ly9vcGVuYmFua2luZy5vcmcudWsvdGFuIjoib3BlbmJhbmtpbmcub3JnLnVrIiwiaHR0cDovL29wZW5iYW5raW5nLm9yZy51ay9pc3MiOiIwMDE1ODAwMDAxMDNVQXZBQU0iLCJodHRwOi8vb3BlbmJhbmtpbmcub3JnLnVrL2lhdCI6MTczNTgyNTE5OX0.{\"Data\":{\"DomesticPaymentId\":\"6776972f-e9af-ad6a-8cdd-ff2099bd2475\",\"Status\":\"Pending\",\"StatusUpdateDateTime\":\"2025-01-02T13:39:59.455059Z\",\"CreationDateTime\":\"2025-01-02T13:39:59.455059Z\",\"ConsentId\":\"6d2e1641-e486-4a3a-936b-065628f2a926\",\"Initiation\":{\"RemittanceInformation\":{\"Unstructured\":\"Shipment fee\"},\"DebtorAccount\":{\"SchemeName\":\"UK.OBIE.SortCodeAccountNumber\",\"Identification\":\"04290953215338\",\"Name\":\"Acme Corporation\"},\"EndToEndIdentification\":\"E2E123\",\"InstructionIdentification\":\"ID412\",\"CreditorAccount\":{\"Name\":\"Receiver Co.\",\"SchemeName\":\"UK.OBIE.SortCodeAccountNumber\",\"Identification\":\"11223321325698\"},\"InstructedAmount\":{\"Amount\":\"1.00\",\"Currency\":\"GBP\"}}},\"Links\":{\"Self\":\"https://sandbox-oba.revolut.com/domestic-payments/6776972f-e9af-ad6a-8cdd-ff2099bd2475\"},\"Meta\":{\"TotalPages\":1}}".as_bytes() };
    // change per JWT
    let jwt_size = jwt.len();

    let mut padded_jwt: [u8; MAX_JWT_SIZE] = [0; MAX_JWT_SIZE];
    for i in 0..jwt.len() {
        padded_jwt[i] = jwt[i];
    }

    let jwt_data: BoundedVec<u8, MAX_JWT_SIZE> = BoundedVec {
        storage: padded_jwt,
        len: jwt_size
    };

    let consent_id_value = comptime { "6d2e1641-e486-4a3a-936b-065628f2a926".as_bytes() };
    let amount = comptime { "1.00".as_bytes() };
    let unstructured = comptime { "Shipment fee".as_bytes() };

    let mut amount_padded: [u8; MAX_AMOUNT_VALUE_LENGTH] = [0; MAX_AMOUNT_VALUE_LENGTH];
    for i in 0..amount.len() {
        amount_padded[i] = amount[i];
    }
    let amount_value: BoundedVec<u8, MAX_AMOUNT_VALUE_LENGTH> = BoundedVec { storage: amount_padded, len: amount.len() };

    let mut unstructured_padded: [u8; MAX_UNSTRUCTURED_LENGTH] = [0; MAX_UNSTRUCTURED_LENGTH];
    for i in 0..unstructured.len() {
        unstructured_padded[i] = unstructured[i];
    }

    let unstructured_value: BoundedVec<u8, MAX_UNSTRUCTURED_LENGTH> = BoundedVec { storage: unstructured_padded, len: unstructured.len() };

    main(
        signature_limbs,
        modulus_limbs,
        redc_limbs,
        jwt_data,
        consent_id_value,
        amount_value,
        unstructured_value
    );
}
