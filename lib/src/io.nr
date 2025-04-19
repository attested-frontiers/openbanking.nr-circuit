use crate::constants::{
    CURRENCY_CODE_VALUE_LENGTH, MAX_AMOUNT_VALUE_LENGTH, MAX_PAYLOAD_LENGTH, PAYMENT_ID_LENGTH,
    SORT_CODE_VALUE_LENGTH,
};
use nodash::ArrayExtensions;
use std::hash::poseidon2::Poseidon2;

pub struct OpenbankingVerifierParams {
    signature_limbs: [u128; 18],
    modulus_limbs: [u128; 18],
    redc_limbs: [u128; 18],
    partial_hash_start: [u32; 8],
    header_delimiter_index: u32,
    payload: BoundedVec<u8, MAX_PAYLOAD_LENGTH>,
}

pub struct OpenbankingVerifierReturn {
    amount: BoundedVec<u8, MAX_AMOUNT_VALUE_LENGTH>,
    currency_code: [u8; CURRENCY_CODE_VALUE_LENGTH],
    payment_id: [u8; PAYMENT_ID_LENGTH],
    sort_code: [u8; SORT_CODE_VALUE_LENGTH],
}

impl OpenbankingVerifierReturn {

    /**
     * Provides a commitment over the sort/bank code and currency code to bind a payment to a target account/ currency
     *
     * @return commitment to the recipient account and currency used
     */
    pub fn recipient_commitment(self) -> Field {
        let sort_code = Field::from_le_bytes::<SORT_CODE_VALUE_LENGTH>(self.sort_code);
        let currency_code = Field::from_le_bytes::<CURRENCY_CODE_VALUE_LENGTH>(self.currency_code);
        Poseidon2::hash([sort_code, currency_code], 2)
    }

    /**
     * Recipient commitment with salt
     *
     * @param salt - salt to be used to blind the commitment
     * @return commitment with salt
     */
    pub fn salted_recipient_commitment(self, salt: Field) -> Field {
        let sort_code = Field::from_le_bytes::<SORT_CODE_VALUE_LENGTH>(self.sort_code);
        let currency_code = Field::from_le_bytes::<CURRENCY_CODE_VALUE_LENGTH>(self.currency_code);
        Poseidon2::hash([sort_code, currency_code, salt], 3)
    }

    /**
     * Convert payment amount as bytes to number 
     * 
     * @return - amount as number
     */
    pub fn parse_amount(self) -> u128 {
        // convert amount from bytes to field and add 4 decimals for USDC decimal conversion
        let amount_vec_length = self.amount.len();
        let mut converted: Field = 0;
        let mut pow: Field = 10.pow_32(amount_vec_length as Field - 2);
        for i in 0..MAX_AMOUNT_VALUE_LENGTH {
            let byte = self.amount.storage[i];
            if (i < amount_vec_length) & (byte != 0x2E) {
                let val = (byte - 0x30) as Field;
                converted = converted + val * pow;
                pow = pow / 10;
            }
        }
        (converted * 10.pow_32(4)) as u128
    }

    /**
     * Computes a nullifier from payment id
     * 
     * @return - nullifier
     */
    pub fn payment_nullifier(self) -> Field {
        let payment_id_packed = pack_bytes::<PAYMENT_ID_LENGTH>(self.payment_id);
        Poseidon2::hash(payment_id_packed, 2)
    }
}

// todo: from nodash, need to use dep when updated
/**
 * Packs a byte array into an array of Fields
 * 
 * @return - packed bytes
 */
fn pack_bytes<let N: u32>(bytes: [u8; N]) -> [Field; N / 31 + 1] {
    let bytes_padded = bytes.pad_end::<(N / 31 + 1) * 31>(0);
    let mut res = [0 as Field; N / 31 + 1];
    for i in 0..N / 31 + 1 {
        let chunk = bytes_padded.slice::<31>(i * 31);
        res[i] = Field::from_le_bytes::<31>(chunk);
    }
    res
}
