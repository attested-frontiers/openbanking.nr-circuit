use aztec::protocol_types::utils::field::field_from_bytes;
use std::hash::poseidon2::Poseidon2;
pub fn bytes_to_num<let MAX_AMOUNT_VALUE_LENGTH: u32>(
    amount_value: BoundedVec<u8, MAX_AMOUNT_VALUE_LENGTH>,
) -> U128 {
    // convert amount from bytes to field and add 4 decimals for USDC decimal conversion
    let mut converted: Field = 0;
    let mut pow: Field = 10.pow_32(amount_value.len as Field - 2);
    for i in 0..MAX_AMOUNT_VALUE_LENGTH {
        let byte = amount_value.storage[i];
        if (i < amount_value.len) & (byte != 0x2E) {
            let val = (byte - 0x30) as Field;
            converted = converted + val * pow;
            pow = pow / 10;
        }
    }
    U128::from_integer(converted * 10.pow_32(4))
}



pub fn hash_pubkey(modulus: [Field; 18], redc: [Field; 18]) -> Field {
    let mut dkim_preimage: [Field; 18] = [0; 18];
    for i in 0..9 {
        let low_index = i * 2;
        let hi_index = i * 2 + 1;
        let modulus_hi = modulus[hi_index] * 2.pow_32(120);
        let redc_hi = redc[hi_index] * 2.pow_32(120);
        dkim_preimage[i] = modulus_hi + modulus[low_index];
        dkim_preimage[i + 9] = redc_hi + redc[low_index];
    }
    Poseidon2::hash(dkim_preimage, 18)
}