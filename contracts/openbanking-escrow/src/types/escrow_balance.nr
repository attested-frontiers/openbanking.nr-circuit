use aztec::protocol_types::traits::{Serialize, Deserialize, Packable};
use std::meta::derive;

pub global ESCROW_BALANCE_SERIALIZED_LEN: u32 = 3;

#[derive(Serialize, Deserialize, Packable, Eq)]
struct EscrowBalance {
    balance: U128,
    initialized: bool,
    // block number the escrow owner can withdraw at
    withdrawable_at: Field,
}