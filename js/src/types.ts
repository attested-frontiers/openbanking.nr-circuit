export type BoundedVec = {
  storage: string[] | number[]
  len: string | number
};

export type OpenBankingDomesticCircuitInputs = {
  signature_limbs: string[] | number[]
  modulus_limbs: string[] | number[]
  redc_limbs: string[] | number[]
  partial_hash_start: string[] | number[]
  header_delimiter_index: string | number
  payload: BoundedVec
};

export type OpenBankingDomesticContractInputs = {
  signature_limbs: string[] | number[]
  modulus_limbs: string[] | number[]
  redc_limbs: string[] | number[]
  partial_hash_start: string[] | number[]
  header_delimiter_index: string | number
  payload: string[] | number[]
  payload_length: string | number
};

export type OpenBankingDomesticCircuitOutputsRaw = {
  amount: BoundedVec
  currency_code: string[]
  payment_id: string[]
  sort_code: string[]
};

export type OpenBankingDomesticCircuitOutputs = {
  amount: number
  currency_code: string
  payment_id: string
  sort_code: string
};
