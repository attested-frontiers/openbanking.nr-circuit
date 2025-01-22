use bignum::{params::BigNumParams, RuntimeBigNum};
use json_parser::JSON1kb::JSON;
use rsa_pss::rsa::verify_sha256_pss;

pub global MAX_JWT_SIZE: u32 = 1536;
pub global MAX_PAYLOAD_LENGTH: u32 = 1024;

pub global PAYLOAD_LENGTH: u32 = 1242;

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
    hash: [u8; 32],
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

    // verify signature over payload
    assert(verify_sha256_pss(hash, signature, 2048));

    // TODO: First attempt at extracting payload away from header. Needs a refactor
    let mut json_payload_bytes: [u8; MAX_PAYLOAD_LENGTH] = [32; MAX_PAYLOAD_LENGTH];
    let mut header_delimiter_found = false;
    let mut index = 0;
    for i in 0..PAYLOAD_LENGTH {
        if(i < data.len & header_delimiter_found) {
            json_payload_bytes[index] = data.get_unchecked(i);
            index += 1;
        } else {
            if data.get_unchecked(i) == 0x2E {
                header_delimiter_found = true;
            }
        }
    }

    // init JSON
    let json: JSON = JSON::parse_json(json_payload_bytes);

    let mut nested_json = json.get_object(PAYLOAD_DATA_KEY).unwrap();
    // extract consent id;
    let consent_id_result = nested_json.get_string_unchecked(CONSENT_ID_KEY);
    assert(consent_id_result.storage == consent_id_value);
    // extract amount
    let mut nested_json2 = nested_json.get_object(INITIATION_KEY).unwrap();
    let mut nested_json_3 = nested_json2.get_object(INSTRUCTED_AMOUNT_KEY).unwrap();
    let amount_result = nested_json_3.get_string_unchecked(AMOUNT_KEY);
    assert(amount_result.storage == amount_value.storage);

    let mut nested_json_4 = nested_json2.get_object(REMITTANCE_KEY).unwrap();
    let unstructured_result = nested_json_4.get_string_unchecked(UNSTRUCTURED_KEY);
    assert(unstructured_result.storage == unstructured_value.storage);
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

    // todo: build bounded vec from string to bytes
    // eyJraWQiOiJvSjQwLUcxVklxbUU2eUhuYnA4S1E1Qmk2bXciLCJhbGciOiJQUzI1NiIsImNyaXQiOlsiYjY0IiwiaHR0cDovL29wZW5iYW5raW5nLm9yZy51ay9pYXQiLCJodHRwOi8vb3BlbmJhbmtpbmcub3JnLnVrL2lzcyIsImh0dHA6Ly9vcGVuYmFua2luZy5vcmcudWsvdGFuIl0sImI2NCI6ZmFsc2UsImh0dHA6Ly9vcGVuYmFua2luZy5vcmcudWsvdGFuIjoib3BlbmJhbmtpbmcub3JnLnVrIiwiaHR0cDovL29wZW5iYW5raW5nLm9yZy51ay9pc3MiOiIwMDE1ODAwMDAxMDNVQXZBQU0iLCJodHRwOi8vb3BlbmJhbmtpbmcub3JnLnVrL2lhdCI6MTczNTgyNTE5OX0.{"Data":{"DomesticPaymentId":"6776972f-e9af-ad6a-8cdd-ff2099bd2475","Status":"Pending","StatusUpdateDateTime":"2025-01-02T13:39:59.455059Z","CreationDateTime":"2025-01-02T13:39:59.455059Z","ConsentId":"6d2e1641-e486-4a3a-936b-065628f2a926","Initiation":{"RemittanceInformation":{"Unstructured":"Shipment fee"},"DebtorAccount":{"SchemeName":"UK.OBIE.SortCodeAccountNumber","Identification":"04290953215338","Name":"Acme Corporation"},"EndToEndIdentification":"E2E123","InstructionIdentification":"ID412","CreditorAccount":{"Name":"Receiver Co.","SchemeName":"UK.OBIE.SortCodeAccountNumber","Identification":"11223321325698"},"InstructedAmount":{"Amount":"1.00","Currency":"GBP"}}},"Links":{"Self":"https://sandbox-oba.revolut.com/domestic-payments/6776972f-e9af-ad6a-8cdd-ff2099bd2475"},"Meta":{"TotalPages":1}}
    let data_vec: BoundedVec<u8, MAX_JWT_SIZE> = BoundedVec {
        storage: [101,121,74,114,97,87,81,105,79,105,74,118,83,106,81,119,76,85,99,120,86,107,108,120,98,85,85,50,101,85,104,117,89,110,65,52,83,49,69,49,81,109,107,50,98,88,99,105,76,67,74,104,98,71,99,105,79,105,74,81,85,122,73,49,78,105,73,115,73,109,78,121,97,88,81,105,79,108,115,105,89,106,89,48,73,105,119,105,97,72,82,48,99,68,111,118,76,50,57,119,90,87,53,105,89,87,53,114,97,87,53,110,76,109,57,121,90,121,53,49,97,121,57,112,89,88,81,105,76,67,74,111,100,72,82,119,79,105,56,118,98,51,66,108,98,109,74,104,98,109,116,112,98,109,99,117,98,51,74,110,76,110,86,114,76,50,108,122,99,121,73,115,73,109,104,48,100,72,65,54,76,121,57,118,99,71,86,117,89,109,70,117,97,50,108,117,90,121,53,118,99,109,99,117,100,87,115,118,100,71,70,117,73,108,48,115,73,109,73,50,78,67,73,54,90,109,70,115,99,50,85,115,73,109,104,48,100,72,65,54,76,121,57,118,99,71,86,117,89,109,70,117,97,50,108,117,90,121,53,118,99,109,99,117,100,87,115,118,100,71,70,117,73,106,111,105,98,51,66,108,98,109,74,104,98,109,116,112,98,109,99,117,98,51,74,110,76,110,86,114,73,105,119,105,97,72,82,48,99,68,111,118,76,50,57,119,90,87,53,105,89,87,53,114,97,87,53,110,76,109,57,121,90,121,53,49,97,121,57,112,99,51,77,105,79,105,73,119,77,68,69,49,79,68,65,119,77,68,65,120,77,68,78,86,81,88,90,66,81,85,48,105,76,67,74,111,100,72,82,119,79,105,56,118,98,51,66,108,98,109,74,104,98,109,116,112,98,109,99,117,98,51,74,110,76,110,86,114,76,50,108,104,100,67,73,54,77,84,99,122,78,84,103,121,78,84,69,53,79,88,48,46,123,34,68,97,116,97,34,58,123,34,68,111,109,101,115,116,105,99,80,97,121,109,101,110,116,73,100,34,58,34,54,55,55,54,57,55,50,102,45,101,57,97,102,45,97,100,54,97,45,56,99,100,100,45,102,102,50,48,57,57,98,100,50,52,55,53,34,44,34,83,116,97,116,117,115,34,58,34,80,101,110,100,105,110,103,34,44,34,83,116,97,116,117,115,85,112,100,97,116,101,68,97,116,101,84,105,109,101,34,58,34,50,48,50,53,45,48,49,45,48,50,84,49,51,58,51,57,58,53,57,46,52,53,53,48,53,57,90,34,44,34,67,114,101,97,116,105,111,110,68,97,116,101,84,105,109,101,34,58,34,50,48,50,53,45,48,49,45,48,50,84,49,51,58,51,57,58,53,57,46,52,53,53,48,53,57,90,34,44,34,67,111,110,115,101,110,116,73,100,34,58,34,54,100,50,101,49,54,52,49,45,101,52,56,54,45,52,97,51,97,45,57,51,54,98,45,48,54,53,54,50,56,102,50,97,57,50,54,34,44,34,73,110,105,116,105,97,116,105,111,110,34,58,123,34,82,101,109,105,116,116,97,110,99,101,73,110,102,111,114,109,97,116,105,111,110,34,58,123,34,85,110,115,116,114,117,99,116,117,114,101,100,34,58,34,83,104,105,112,109,101,110,116,32,102,101,101,34,125,44,34,68,101,98,116,111,114,65,99,99,111,117,110,116,34,58,123,34,83,99,104,101,109,101,78,97,109,101,34,58,34,85,75,46,79,66,73,69,46,83,111,114,116,67,111,100,101,65,99,99,111,117,110,116,78,117,109,98,101,114,34,44,34,73,100,101,110,116,105,102,105,99,97,116,105,111,110,34,58,34,48,52,50,57,48,57,53,51,50,49,53,51,51,56,34,44,34,78,97,109,101,34,58,34,65,99,109,101,32,67,111,114,112,111,114,97,116,105,111,110,34,125,44,34,69,110,100,84,111,69,110,100,73,100,101,110,116,105,102,105,99,97,116,105,111,110,34,58,34,69,50,69,49,50,51,34,44,34,73,110,115,116,114,117,99,116,105,111,110,73,100,101,110,116,105,102,105,99,97,116,105,111,110,34,58,34,73,68,52,49,50,34,44,34,67,114,101,100,105,116,111,114,65,99,99,111,117,110,116,34,58,123,34,78,97,109,101,34,58,34,82,101,99,101,105,118,101,114,32,67,111,46,34,44,34,83,99,104,101,109,101,78,97,109,101,34,58,34,85,75,46,79,66,73,69,46,83,111,114,116,67,111,100,101,65,99,99,111,117,110,116,78,117,109,98,101,114,34,44,34,73,100,101,110,116,105,102,105,99,97,116,105,111,110,34,58,34,49,49,50,50,51,51,50,49,51,50,53,54,57,56,34,125,44,34,73,110,115,116,114,117,99,116,101,100,65,109,111,117,110,116,34,58,123,34,65,109,111,117,110,116,34,58,34,49,46,48,48,34,44,34,67,117,114,114,101,110,99,121,34,58,34,71,66,80,34,125,125,125,44,34,76,105,110,107,115,34,58,123,34,83,101,108,102,34,58,34,104,116,116,112,115,58,47,47,115,97,110,100,98,111,120,45,111,98,97,46,114,101,118,111,108,117,116,46,99,111,109,47,100,111,109,101,115,116,105,99,45,112,97,121,109,101,110,116,115,47,54,55,55,54,57,55,50,102,45,101,57,97,102,45,97,100,54,97,45,56,99,100,100,45,102,102,50,48,57,57,98,100,50,52,55,53,34,125,44,34,77,101,116,97,34,58,123,34,84,111,116,97,108,80,97,103,101,115,34,58,49,125,125,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        len: PAYLOAD_LENGTH
    };
    
    // todo: move hash inside circuit
    let hash: [u8; 32] = dep::std::hash::sha256_var(data_vec.storage, data_vec.len as u64);

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
        hash,
        signature_limbs,
        modulus_limbs,
        redc_limbs,
        data_vec,
        consent_id_value,
        amount_value,
        unstructured_value
    );
}
