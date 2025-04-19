use aztec::{
    keys::getters::{get_nsk_app, get_public_keys},
    macros::notes::note,
    note::utils::compute_note_hash_for_nullify,
    prelude::PrivateContext,
    protocol_types::{
        address::AztecAddress,
        constants::GENERATOR_INDEX__NOTE_NULLIFIER,
        hash::poseidon2_hash_with_separator,
        traits::{Hash, Packable, Serialize},
    },
};

#[derive(Eq)]
#[note]
pub struct EscrowOwnerNote {
    commitment: Field,
    owner: AztecAddress,
    randomness: Field,
}

impl EscrowOwnerNote {
    /**
     * Create a new escrow owner note
     *
     * @param commitment - hash of user sort code and currency code
     * @param randomness - note randomness
     * @param owner - owner of the note
     */
    pub fn new(commitment: Field, randomness: Field, owner: AztecAddress) -> Self {
        EscrowOwnerNote { commitment, randomness, owner }
    }
}
