use aztec::protocol_types::utils::field::field_from_bytes;

pub fn bytes_to_num<let MAX_AMOUNT_VALUE_LENGTH: u32>(
    amount_value: BoundedVec<u8, MAX_AMOUNT_VALUE_LENGTH>,
) -> U128 {
    // convert amount from bytes to field and add 6 decimals
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

pub fn pack_bytes<let N: u32>(bytes: [u8; N]) -> [Field; N / 31 + 1] {
    let bytes_padded = bytes.pad_end::<(N / 31 + 1) * 31>(0);
    let mut res = [0 as Field; N / 31 + 1];
    for i in 0..N / 31 + 1 {
        let chunk = bytes_padded.slice::<31>(i * 31);
        res[i] = field_from_bytes(chunk, false);
    }
    res
}
