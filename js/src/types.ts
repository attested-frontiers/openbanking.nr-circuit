export type BoundedVec = {
    storage: string[] | number[];
    len: string | number;
}

export type OpenBankingCircuitInputs = {
    signature_limbs: string[] | number[],
    modulus_limbs: string[] | number[],
    redc_limbs: string[] | number[],
    partial_hash_start: string[] | number[],
    header_delimiter_index: string | number,
    payload: BoundedVec,
    amount: BoundedVec,
    currency_code: string[] | number[],
    sort_code: string[] | number[]
};