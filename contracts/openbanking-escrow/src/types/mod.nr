use aztec::protocol_types::traits::Serialize;
use openbanking_verifier::constants::{MAX_PAYLOAD_LENGTH, OpenbankingVerifierParams};
mod escrow_balance;
mod escrow_owner_note;
mod config;


#[derive(Serialize)]
pub struct OpenbankingVerifierParamsContract {
    signature_limbs: [Field; 18],
    modulus_limbs: [Field; 18],
    redc_limbs: [Field; 18],
    partial_hash_start: [u32; 8],
    header_delimiter_index: u32,
    payload: [u8; MAX_PAYLOAD_LENGTH],
    payload_length: u32,
}

impl OpenbankingVerifierParamsContract {
    fn unmarshal(params: OpenbankingVerifierParams) -> Self {
        Self {
            signature_limbs: params.signature_limbs,
            modulus_limbs: params.modulus_limbs,
            redc_limbs: params.redc_limbs,
            partial_hash_start: params.partial_hash_start,
            header_delimiter_index: params.header_delimiter_index,
            payload: params.payload.storage,
            payload_length: params.payload.len,
        }
    }

    fn marshal(self) -> OpenbankingVerifierParams {
        // check that payload sequence falls within specified length
        for i in 0..MAX_PAYLOAD_LENGTH {
            assert(
                (i < self.payload_length) | (self.payload[i] == 32),
                "Payload exceeds specified length",
            );
        }

        OpenbankingVerifierParams {
            signature_limbs: self.signature_limbs,
            modulus_limbs: self.modulus_limbs,
            redc_limbs: self.redc_limbs,
            partial_hash_start: self.partial_hash_start,
            header_delimiter_index: self.header_delimiter_index,
            payload: BoundedVec { storage: self.payload, len: self.payload_length },
        }
    }
}
