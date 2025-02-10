use dep::openbanking_verifier::{
    constants::{
        MAX_AMOUNT_VALUE_LENGTH, MAX_PAYLOAD_LENGTH, OpenbankingVerifierParams,
        OpenbankingVerifierReturn,
    },
    verify::{partial_sha256_var_start, verify_openbanking_payment},
};

fn main(params: OpenbankingVerifierParams) -> pub OpenbankingVerifierReturn {
    verify_openbanking_payment(params)
}

// TEST GLOBALS
pub global TEST_HEADER_DELIMITER_INDEX_LENGTH: u32 = 431;
pub global TEST_JWT_LENGTH: u32 = 1242;
pub global TEST_PAYLOAD_LENGTH: u32 = TEST_JWT_LENGTH - TEST_PH_START_PREIMAGE_LENGTH;
pub global TEST_PH_START_PREIMAGE_LENGTH: u32 = 384;

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

    // Revolut JWT
    let jwt = comptime {
        "eyJraWQiOiJvSjQwLUcxVklxbUU2eUhuYnA4S1E1Qmk2bXciLCJhbGciOiJQUzI1NiIsImNyaXQiOlsiYjY0IiwiaHR0cDovL29wZW5iYW5raW5nLm9yZy51ay9pYXQiLCJodHRwOi8vb3BlbmJhbmtpbmcub3JnLnVrL2lzcyIsImh0dHA6Ly9vcGVuYmFua2luZy5vcmcudWsvdGFuIl0sImI2NCI6ZmFsc2UsImh0dHA6Ly9vcGVuYmFua2luZy5vcmcudWsvdGFuIjoib3BlbmJhbmtpbmcub3JnLnVrIiwiaHR0cDovL29wZW5iYW5raW5nLm9yZy51ay9pc3MiOiIwMDE1ODAwMDAxMDNVQXZBQU0iLCJodHRwOi8vb3BlbmJhbmtpbmcub3JnLnVrL2lhdCI6MTczNTgyNTE5OX0.{\"Data\":{\"DomesticPaymentId\":\"6776972f-e9af-ad6a-8cdd-ff2099bd2475\",\"Status\":\"Pending\",\"StatusUpdateDateTime\":\"2025-01-02T13:39:59.455059Z\",\"CreationDateTime\":\"2025-01-02T13:39:59.455059Z\",\"ConsentId\":\"6d2e1641-e486-4a3a-936b-065628f2a926\",\"Initiation\":{\"RemittanceInformation\":{\"Unstructured\":\"Shipment fee\"},\"DebtorAccount\":{\"SchemeName\":\"UK.OBIE.SortCodeAccountNumber\",\"Identification\":\"04290953215338\",\"Name\":\"Acme Corporation\"},\"EndToEndIdentification\":\"E2E123\",\"InstructionIdentification\":\"ID412\",\"CreditorAccount\":{\"Name\":\"Receiver Co.\",\"SchemeName\":\"UK.OBIE.SortCodeAccountNumber\",\"Identification\":\"11223321325698\"},\"InstructedAmount\":{\"Amount\":\"1.00\",\"Currency\":\"GBP\"}}},\"Links\":{\"Self\":\"https://sandbox-oba.revolut.com/domestic-payments/6776972f-e9af-ad6a-8cdd-ff2099bd2475\"},\"Meta\":{\"TotalPages\":1}}"
            .as_bytes()
    };

    // extract beginning of JWT to create partial hash start. Smallest value divisble by block size (64) is
    // 384 in this case
    let mut partial_hash_start_preimage: [u8; TEST_PH_START_PREIMAGE_LENGTH] =
        [0; TEST_PH_START_PREIMAGE_LENGTH];
    for i in 0..partial_hash_start_preimage.len() {
        partial_hash_start_preimage[i] = jwt[i];
    }

    // partial hash start
    let partial_hash_start =
        partial_sha256_var_start::<TEST_PH_START_PREIMAGE_LENGTH>(partial_hash_start_preimage);

    let mut payload: [u8; MAX_PAYLOAD_LENGTH] = [32; MAX_PAYLOAD_LENGTH];
    // extract rest of payload to pass in circuit
    for i in 0..TEST_JWT_LENGTH - TEST_PH_START_PREIMAGE_LENGTH {
        payload[i] = jwt[i + TEST_PH_START_PREIMAGE_LENGTH];
    }

    let payload_vec: BoundedVec<u8, MAX_PAYLOAD_LENGTH> =
        BoundedVec { storage: payload, len: TEST_PAYLOAD_LENGTH };

    let params = OpenbankingVerifierParams {
        signature_limbs,
        modulus_limbs,
        redc_limbs,
        partial_hash_start,
        header_delimiter_index: TEST_HEADER_DELIMITER_INDEX_LENGTH,
        payload: payload_vec,
    };

    let res = main(params);

    let amount = comptime { "1.00".as_bytes() };
    let currency_code = comptime { "GBP".as_bytes() };
    let payment_id = comptime { "6776972f-e9af-ad6a-8cdd-ff2099bd2475".as_bytes() };
    let sort_code = comptime { "04290953215338".as_bytes() };

    let mut amount_padded: [u8; MAX_AMOUNT_VALUE_LENGTH] = [0; MAX_AMOUNT_VALUE_LENGTH];
    for i in 0..amount.len() {
        amount_padded[i] = amount[i];
    }

    assert(amount_padded == res.amount.storage, "Expected amount not equal to extracted amount.");
    assert(
        currency_code == res.currency_code,
        "Expected currency code not equal to extracted currency code.",
    );
    assert(payment_id == res.payment_id, "Expected payment id not equal to extracted payment id.");
    assert(sort_code == res.sort_code, "Expected sort code not equal to extracted sort code.");
}
