// JWT constants
pub global MAX_JWT_SIZE: u32 = 1536;
pub global MAX_PAYLOAD_LENGTH: u32 = 1024;

// Payload value lengths
pub global CURRENCY_CODE_VALUE_LENGTH: u32 = 3;
pub global CURRENCY_CODE_KEY_LENGTH: u32 = 8;
pub global SORT_CODE_KEY_LENGTH: u32 = 14;
pub global SORT_CODE_VALUE_LENGTH: u32 = 14;
pub global AMOUNT_KEY_LENGTH: u32 = 6;
pub global MAX_AMOUNT_VALUE_LENGTH: u32 = 10;
pub global PAYMENT_ID_KEY_LENGTH: u32 = 17;
pub global PAYMENT_ID_LENGTH: u32 = 36;

// Payload keys
pub global AMOUNT_KEY: [u8; AMOUNT_KEY_LENGTH] = comptime { "Amount".as_bytes() };
pub global CURRENCY_CODE_KEY: [u8; CURRENCY_CODE_KEY_LENGTH] = comptime { "Currency".as_bytes() };
pub global CREDITOR_ACCOUNT_KEY: [u8; 15] = comptime { "CreditorAccount".as_bytes() };
pub global INITIATION_KEY: [u8; 10] = comptime { "Initiation".as_bytes() };
pub global INSTRUCTED_AMOUNT_KEY: [u8; 16] = comptime { "InstructedAmount".as_bytes() };
pub global PAYLOAD_DATA_KEY: [u8; 4] = comptime { "Data".as_bytes() };
pub global PAYMENT_ID_KEY: [u8; PAYMENT_ID_KEY_LENGTH] = comptime { "DomesticPaymentId".as_bytes() };
pub global SORT_CODE_KEY: [u8; SORT_CODE_KEY_LENGTH] = comptime { "Identification".as_bytes() };
