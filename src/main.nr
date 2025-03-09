use dep::openbanking_verifier::{
    constants::{MAX_AMOUNT_VALUE_LENGTH, MAX_PAYLOAD_LENGTH,},
    verify::verify_openbanking_payment,
    io::{OpenbankingVerifierParams, OpenbankingVerifierReturn}
};
use zkemail::partial_hash::{partial_sha256_var_start, partial_sha256_var_end};


fn main(params: OpenbankingVerifierParams) -> pub OpenbankingVerifierReturn {
    verify_openbanking_payment(params)
}

// TEST GLOBALS
pub global TEST_HEADER_DELIMITER_INDEX_LENGTH: u32 = 431;
pub global TEST_JWT_LENGTH: u32 = 1242;
pub global TEST_PAYLOAD_LENGTH: u32 = TEST_JWT_LENGTH - TEST_PH_START_PREIMAGE_LENGTH;
pub global TEST_PH_START_PREIMAGE_LENGTH: u32 = 384;

// #[test]
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
    let sort_code = comptime { "11223321325698".as_bytes() };

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

// #[test]
fn test_poseidon2_hashes() {
    let moduluses: [[Field; 18]; 5] = [
        [
            0x9f76c1ec6d8f1d11666b8e9210bfc1,
            0x9faaf8b168eaf3873403ee08847e66,
            0x195b6f04c7def80fa7bdb4cc034088,
            0xff04c3928072ff8b14d8f37c2712d7,
            0x9c5235e5abca6d068f12b22f94188c,
            0x16d6c8ed83f01aca9dc061c5feb6be,
            0xea43d55aaa25323247d78388148c99,
            0x4d6df446b1ce31b3b04dbc7b1e5500,
            0x8276307060097e03ede1ca7b29e925,
            0x35f6a517a2dd059cb6f191949804b6,
            0x27683ac087a341c9301ded685aa6c7,
            0x47ab70111267727b805618c69baf53,
            0xd1e764c3df81a304de46196d2f3a0b,
            0x845fada16ad82f9cd9e3cac3841282,
            0xc337dff76938fe8d4cb131e07f00d7,
            0x1f54778fbc8db85eb0c5496ff053af,
            0x4287bf7a9bb217030f0f54b98cabc2,
            0xd0,
        ],
        [
            0x72f0ae6fd0188462f04b39d466836f,
            0xe87e561754ea1c86aa7f6b39c1d0d8,
            0x1dc23e44e78404556bf7c3c8ee098b,
            0x3e8d2bdc30992c08580af5448815d8,
            0x41bd619e0102af7f03e4a72b1bd110,
            0x9ed8010cf1636c05e7a0f390711155,
            0x83a9949f9c1062c1bf5cdc4aba2a4e,
            0x9f78a17e67d7040851f4f852a8f1db,
            0x5950e977a9f9701f9b4898401c01b7,
            0x7187f15b3773d92ba190e90b1a2dbd,
            0x0c3fe01a43ce0e74119ec4a5fc112b,
            0x6e9be5d892d21fb83c3a2688fa43dc,
            0xc8b4a7cd5c033dd9f0788838711ac7,
            0x37dc42891d82affe086d9d65fa1643,
            0x875ddab4a7a329ab261eeec5d45feb,
            0x302f9895b272465a80997178a2d001,
            0x32f3dd05f6a2fc7bf9de2f5a6ab04d,
            0xa8,
        ],
        [
            0xeabced63d0b101558b85919bdc18ef,
            0x26c28bd513f71998301e71cefe891d,
            0xf1b0a3891d68ad2e81517549ff94e0,
            0x9878b09cb8e7ed125c8fadd940d1ef,
            0x8f829534ffbb8725d8076baf515101,
            0xfebef68ce730276e10b3670f8f6bc3,
            0x29185035557c19915b40654a8b8c7b,
            0x67488b4b60d3e78e776277765933ad,
            0xca056f7c64da61e8613bb557be8561,
            0xc7756d3c85491513d1a7477589159b,
            0x73f4ab5a49fe38301d54701c393aa7,
            0x30341a2e7a5242b8bdc5a5a9ad57ce,
            0xba00dfef6c00abb3d290a47223fd11,
            0xf4db7bf74c533494df319739779163,
            0xaf766d30372e431af756bf83f9a8a6,
            0xb0f0a59a617c7285ae46f36b694d90,
            0x488ea9627268fc59e28584ec5f2cd9,
            0xb9,
        ],
        [
            0x6e17b8be54c2c60e29a3589c64c6a3,
            0xd3f64cf0b74f08293d974c480a62dc,
            0x95910982e21624e239677d68d5206a,
            0x5b771818a1661e7f4342168d378811,
            0x6bd36d192da7b2d22c02c862c08179,
            0x59d6fd0c32f1ee906bf5cb879c075e,
            0xe8577567b120c54ab1308149d8f524,
            0x86acc5a5d1fa9a2d58b9344dc746ba,
            0xd2300caa068e2c058eeff57e11c5ff,
            0x6a2aa11de479e920641dd3c5916e91,
            0xa974113949de5793fa673945ff61a9,
            0x97c28ae65b9bd0090f4beb4935ebfc,
            0x3f0a7dcf145e36abd7d06c84891793,
            0xe77a5e08fd0fa193cf7481b1cac327,
            0x562d31b208144b962045f356aa1cf1,
            0x910ebc8fa00d3ada947301b298f7f2,
            0x440475056a1009e9d1f46030a5d94a,
            0xbd,
        ],
        [
            0x53f4e0523650eac2cf25a8d137a949,
            0x8aa514aa79ddfb14ad539ba6089caf,
            0x11364d0fb2a1fe18b7c6acfa8b080c,
            0x21702e5ff991caf0692e85a50be53e,
            0x1eb37782945b58fe288411139bc05e,
            0xc6227242a22cfbee2b69499615e157,
            0x941e221ef8eebce8c971e97c4c7fcb,
            0xcff8ed09f5a6ecdb505b19e09e32f9,
            0xcd136a4458ed79af0a22e31141d76a,
            0x29b062040a315b0ea187d7f2bd7003,
            0x4659d51b02bbe68a6a297a8d09441b,
            0x7a6d9eec0ca5d777a36859d1c26700,
            0x40aeba9b1ff45bc3ad8e031481d835,
            0x8ff166583e658caa574561e80ec810,
            0x21ac80c3672cee586822845ddc2bfa,
            0xb3d18b761a488941cddb10c14c8887,
            0xf68b666736044f9188b5b9da6d04a4,
            0xab,
        ],
    ];

    let redcs: [[Field; 18]; 5] = [
        [
            0x20536aa29207bb7a575cd98121ee02,
            0xb47be4193844aa326612ef6433f9f6,
            0x9cf79f6de140989b348fa89379d7bb,
            0x3aa11134457882178caa1c95bf16bd,
            0x7a0fba0efd33cf11ff0e11f82bc1b9,
            0x74c565e4fb4bd68e1828eb6813b023,
            0xc2f20fd5646500553314bc9942b662,
            0x8a674829aaa063836140aa55cfd58c,
            0x5889eaafc5cd8e5cd08c8fc457fedd,
            0xe708c149b6d771fda72327883a8426,
            0x902eaaadbf81db211717c659d710af,
            0x412ae650e8b8aae0f3caa6a9920bf7,
            0x3fa6d5bc2c3d688311ee10d0f83cec,
            0x9066e9a6b29f5fdd6c28eeff2bcc02,
            0x6a87ce031b3ff7cd525838797c352c,
            0xc96b5f3a13c67918898b29ad7920e6,
            0xf09dacedeebceda932430a249a5929,
            0x13aa,
        ],
        [
            0x9606960006918e17c6420365ee61d4,
            0x448770dd64fa725828cad527c3c299,
            0x62592758474c6f928266e6f65c2b6b,
            0x689e2220fd335e3325d67812f24d50,
            0x89f53fd6c8a2549088bc9a14a88424,
            0x37a3d0ad53fa2a7bdc1b122b2054c4,
            0x9298402db4aedf3afc16ac45a7d9ed,
            0x32e2e009b87a3b07b224055205f711,
            0x163b8d19a5b9e119b70ff6a91e6393,
            0x935fbfb8843743dc188a2dcc779912,
            0x8f78a7afa56a57459620767364ea1c,
            0x05c61a19d24de097334d508520e661,
            0x0576a47052e35f260f712cdec041c8,
            0xeba893329072428ce86d37acac854f,
            0xe2c7e1a8893973c91f1affdf378a6e,
            0x35397d542c0548c569e399424a2a54,
            0x2359289c7ea2e25180ce3847819109,
            0x185a,
        ],
        [
            0x8a1c5b2f70da4c85353a91405a3853,
            0xb6bd35fe7a9993346bf40e9200319d,
            0x2bf6927740b8421d6f8f885c5acbbf,
            0xa51b8b38d4a9ed8ac238ae20794da8,
            0xe4ab3e0984d040c47b1460fcd878fb,
            0x25754b6adbc2d3c7649889b4a01a34,
            0x91ede1b6a8b982c2375b9bba90d92b,
            0x8ddfa5b18a4742c2c6c955afe49d84,
            0x8b2462a5a21da9eb7432857fbbaaf4,
            0x1cdb71f6ae6090d05c53414cd77e6a,
            0x8f12bc59abe44cbe9513c4fb366be1,
            0x0f5f5aa392c472fae41da011818981,
            0xe220d68299b0a960f66413bd3b7dc7,
            0xdb1565842a2cbf3761e766f2374ba8,
            0x23ef13c9ec3b74bd6d726497a70f9d,
            0x2df16957c6b91e3a26e2a7dca27e0b,
            0x4ee03b0663a6e7afabc75e0344aaab,
            0x161b,
        ],
        [
            0x8b2f64bceb4f7322a1892e4afed7a2,
            0x06bd3492fae29d3ef7fa17d44f13a3,
            0xf9d28587a7b5306102de284c6af775,
            0x7307cd4f8598b0103073f01d64be91,
            0x0c8b91cdad07bfe08013a13f6b4ef9,
            0x3ae92728895d3bebe29dc0e7f80697,
            0x783f11b1b94ea882921114503f8466,
            0xee45bd32660f4078332705a499689d,
            0xc390cd856dc9380aa8d4aaa630e01a,
            0x8b1168d75efe8f513b215bbb14e548,
            0x977bf8dc25cdb9a1d00301a99ab432,
            0x26ee03f585a4ed73a300e763e7c285,
            0x6f2aa5a036bf842557e734f45d9858,
            0xbb67ae77a1276e293092b6d4941666,
            0x9e60d7a765b37db83501e71beec053,
            0x50e3c65c4a0386d1d674d3680914cd,
            0x3b98aaaa7da17667f4bb21257cf4f6,
            0x15a4,
        ],
        [
            0x1bc3ba714c79e6ea406b76000c897d,
            0xe80e3e98dfd4f9e6a8f711a5360bb4,
            0x1f51410637a462b6d3b383c2279503,
            0x8ccbf5e4d719703ce883a2eeef20a0,
            0x499a9b8fe78218f2f266a4f72ef2a8,
            0xb08bd8044d41445928bfda98750f0a,
            0x9d7974a23107a0ca7020a97d964fc4,
            0x0e7acbc37d788a410ab679c26acf41,
            0xeb334c2fb63ea2f65abc995159e56e,
            0x96a2531f4b0b4ad14410496a45f25e,
            0xe5287ebd7ae1945a3dbe9a38c0b012,
            0xfb7d4c3cf84f02b0752f9e5802af39,
            0x76cb3b25b0d54de92ce03fd93dd749,
            0x768afbc61af80cc4b4cd0b48db658d,
            0x22954ff874f609b81892bd3ad7b935,
            0x6bd94a7a6df27eef8e710a83de6f35,
            0xae77b841eb2a2a2bdd189569a248a7,
            0x17d1,
        ],
    ];

    for i in 0..5 {
        let modulus = moduluses[i];
        let redc = redcs[i];
        let mut dkim_preimage = [0; 18];
        // compose limbs
        for i in 0..9 {
            let low_index = i * 2;
            let hi_index = i * 2 + 1;
            let modulus_hi = modulus[hi_index] * 2.pow_32(120);
            let redc_hi = redc[hi_index] * 2.pow_32(120);
            dkim_preimage[i] = modulus_hi + modulus[low_index];
            dkim_preimage[i + 9] = redc_hi + redc[low_index];
        }
        let hash = std::hash::poseidon2::Poseidon2::hash(dkim_preimage, 18);
        println(f"Hash {i}: {hash}");
    }
}