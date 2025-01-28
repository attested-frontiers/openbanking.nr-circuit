pub unconstrained fn get_delimiter_index<let HEADER_LEN: u32, let JWT_SIZE: u32>(data: BoundedVec<u8, JWT_SIZE>) -> u32 {
    let mut header_delimiter_index = 0;
    for i in 0..HEADER_LEN {
        let value = data.get_unchecked(i);
        if (header_delimiter_index == 0) & (value == 0x2E) {
            header_delimiter_index = i;
        }
    }
    header_delimiter_index
}

pub unconstrained fn get_payload<let HEADER_LEN: u32, let PAYLOAD_LEN: u32>(
    data: BoundedVec<u8, HEADER_LEN>,
    delimeter_index: u32
) -> BoundedVec<u8, PAYLOAD_LEN> {
    let mut len =  data.len - delimeter_index - 1;
    let mut storage: [u8; PAYLOAD_LEN] = [32; PAYLOAD_LEN];
    for i in 0..len {
        storage[i] = data.get_unchecked(delimeter_index + i + 1);
    }
    BoundedVec {
        storage,
        len
    }
} 

pub fn check_delimiter_index<let HEADER_LEN: u32, let JWT_SIZE: u32>(data: BoundedVec<u8, JWT_SIZE>, delimeter_index: u32) {
    assert(data.len > delimeter_index, "Delimiter index exceeds data length.");
    for i in 0..HEADER_LEN {
        if(i < delimeter_index) {
            assert(data.get_unchecked(i) != 0x2E);
        }
    }
    assert(data.get_unchecked(delimeter_index) == 0x2E);
}

pub fn compare_payload<let JWT_SIZE: u32, let PAYLOAD_LEN: u32>(
    data: BoundedVec<u8, JWT_SIZE>,
    payload: BoundedVec<u8, PAYLOAD_LEN>,
    delimeter_index: u32 
) {
    assert(delimeter_index + payload.len <= data.len, "Payload length exceeds JWT size");
    for i in 0..PAYLOAD_LEN {
        let data_value = data.get_unchecked(delimeter_index + i + 1);
        let payload_value = payload.get_unchecked(i);
        if i < payload.len {
            assert(data_value == payload_value);
        }
    }
}