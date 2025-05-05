use aztec::protocol_types::utils::field::field_from_bytes;
use std::hash::poseidon2::Poseidon2;


/**
* Convert payment amount as bytes to number 
*
* @param amount_value - payment amount
* @return - payment amount in number
*/
pub fn bytes_to_num<let MAX_AMOUNT_VALUE_LENGTH: u32>(
    amount_value: BoundedVec<u8, MAX_AMOUNT_VALUE_LENGTH>,
) -> u128 {
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
    (converted * 10.pow_32(4)) as u128
}


/**
* Creates a poseidon hash of a pubkey
*
* @param modulus - limb format of pubkey modulus
* @param rec - limb format of pubkey reduction paramets
* @return - hash of the pubkey
*/
pub fn hash_pubkey(modulus: [u128; 18], redc: [u128; 18]) -> Field {
    let mut dkim_preimage: [Field; 18] = [0; 18];
    for i in 0..9 {
        let low_index = i * 2;
        let hi_index = i * 2 + 1;
        let modulus_hi = modulus[hi_index] as Field * 2.pow_32(120);
        let redc_hi = redc[hi_index] as Field * 2.pow_32(120);
        dkim_preimage[i] = modulus_hi + modulus[low_index] as Field;
        dkim_preimage[i + 9] = redc_hi + redc[low_index] as Field;
    }
    Poseidon2::hash(dkim_preimage, 18)
}