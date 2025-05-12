use dep::aztec::macros::aztec;

mod constants;
mod library_functions;
mod test;
mod types;
mod utils;

#[aztec]
contract OpenbankingEscrow {

    use crate::{
        constants::MAX_KEY_HASHES_PER_TX,
        library_functions::withdraw_tokens,
        types::{
            config::Config, escrow_balance::EscrowBalance, escrow_owner_note::EscrowOwnerNote,
            openbanking::OpenbankingVerifierParamsContract,
        },
        utils::hash_pubkey,
    };
    use aztec::{
        macros::{
            functions::{initializer, internal, private, public, utility, view},
            storage::storage,
        },
        messages::logs::note::encode_and_encrypt_note,
        note::note_getter::MAX_NOTES_PER_PAGE,
        prelude::{AztecAddress, Map, PrivateMutable, PublicImmutable, PublicMutable},
    };
    use openbanking_verifier::{io::OpenbankingVerifierReturn, verify::verify_openbanking_payment};
    use std::hash::poseidon2::Poseidon2;
    use token::Token;

    #[storage]
    struct Storage<Context> {
        config: PublicImmutable<Config, Context>,
        escrow_owners: Map<AztecAddress, PrivateMutable<EscrowOwnerNote, Context>, Context>,
        escrow_balances: Map<Field, PublicMutable<EscrowBalance, Context>, Context>,
        pubkey_registry: Map<Field, PublicMutable<bool, Context>, Context>,
    }

    /**
     * Contract constructor that stores token contract address and pubkey hashes
     * 
     * @param token_address - address of the token contract linked to escrow
     * @param key_hashes - array of pubkey hashes computed from valid pubkeys in JWKS
     */
    #[public]
    #[initializer]
    fn constructor(token_address: AztecAddress, key_hashes: [Field; MAX_KEY_HASHES_PER_TX]) {
        storage.config.initialize(Config::new(token_address, context.msg_sender()));
        for i in 0..MAX_KEY_HASHES_PER_TX {
            if key_hashes[i] != 0 {
                storage.pubkey_registry.at(key_hashes[i]).write(true);
            }
        }
    }

    /**
     * Adds hashes of new valid pubkey to pubkey registry
     * 
     * @param key_hashes - array of pubkey hashes computed from valid pubkeys in JWKS
     */
    #[public]
    fn add_key_hashes(key_hashes: [Field; MAX_KEY_HASHES_PER_TX]) {
        let admin = storage.config.read().admin;
        assert(admin == context.msg_sender(), "Only admin can add key hashes");
        for i in 0..MAX_KEY_HASHES_PER_TX {
            if key_hashes[i] != 0 {
                storage.pubkey_registry.at(key_hashes[i]).write(true);
            }
        }
    }

    /**
     * Removes hashes of revoked pubkeys from pubkey registry
     * 
     * @param key_hashes - array of pubkey hashes computed from revoked pubkeys no longer in JWKS
     */
    #[public]
    fn revoke_keys(key_hashes: [Field; MAX_KEY_HASHES_PER_TX]) {
        let admin = storage.config.read().admin;
        assert(admin == context.msg_sender(), "Only admin can revoke key hashes");
        for i in 0..MAX_KEY_HASHES_PER_TX {
            if key_hashes[i] != 0 {
                storage.pubkey_registry.at(key_hashes[i]).write(false);
            }
        }
    }

    /**
     * Increments pre-existing escrow balance
     * 
     * @param amount - amount to increase the escrow balance by
     */
    #[private]
    fn increment_escrow_balance(amount: u128) {
        let escrow_owner = context.msg_sender();
        let escrow_contract = context.this_address();
        // TODO: Perform check that note exists
        let mut escrow_owner_note = storage.escrow_owners.at(escrow_owner).get_note().note;
        assert(escrow_owner_note.owner == escrow_owner, "Cannot use escrow owner note");
        storage.escrow_owners.at(escrow_owner).replace(escrow_owner_note).emit(
            encode_and_encrypt_note(&mut context, escrow_owner, escrow_owner),
        );
        // transfer private token balance to public balance of escrow
        Token::at(storage.config.read().token)
            .transfer_to_public(escrow_owner, escrow_contract, amount, 0)
            .call(&mut context);

        OpenbankingEscrow::at(escrow_contract)
            ._increment_escrow_balance(escrow_owner_note.commitment, amount)
            .enqueue(&mut context);
    }

    /**
     * Initializes an escrow balance
     * 
     * @param sort_code - sort code of the escrow balance owner
     * @param currency_code - currency code for the currency used in the escrow balance
     * @param amount - amount to mark as intial balance
     * @param randomness - randomness used to create the EscrowOwnerNote
     */
    #[private]
    fn init_escrow_balance(
        sort_code: Field,
        currency_code: Field,
        amount: u128,
        randomness: Field,
    ) {
        let escrow_owner = context.msg_sender();
        let escrow_contract = context.this_address();
        // create commitment
        let commitment = Poseidon2::hash([sort_code, currency_code], 2);

        // init escrow owner note
        let mut escrow_owner_note = EscrowOwnerNote::new(commitment, randomness, escrow_owner);

        storage.escrow_owners.at(escrow_owner).initialize(escrow_owner_note).emit(
            encode_and_encrypt_note(&mut context, escrow_owner, escrow_owner),
        );

        OpenbankingEscrow::at(escrow_contract)._init_escrow_balance(commitment, amount).enqueue(
            &mut context,
        );

        // transfer private token balance to public balance of escrow
        let token_contract = storage.config.read().token;
        Token::at(token_contract).transfer_to_public(escrow_owner, escrow_contract, amount, 0).call(
            &mut context,
        );
    }

    /**
     * Proves an Openbanking payment occurred. Computes commitment from payment verifier circuit extracted values and
     * decrements balance for the EscrowBalance matching that commitment
     * 
     * @param openbanking_params - contract friendly params of Openbanking.nr payment verifier circuit
     */
    #[private]
    fn prove_payment_and_claim(openbanking_params: OpenbankingVerifierParamsContract) {
        // prove openbanking payment
        let result: OpenbankingVerifierReturn =
            verify_openbanking_payment(openbanking_params.marshal());

        // escrow commitment retrieved from sort / bank account code and currency
        // todo: add commitment salt
        let escrow_commitment = result.recipient_commitment();

        // parse the amount sent in the open banking transfer
        let amount = result.parse_amount();

        // hash payment id and emit as a nullifier
        // should fail if payment id already exists
        let payment_nullifier = result.payment_nullifier();
        context.push_nullifier(payment_nullifier);

        // update public balance
        let escrow_contract = OpenbankingEscrow::at(context.this_address());
        escrow_contract
            ._apply_payment(
                openbanking_params.modulus_limbs,
                openbanking_params.redc_limbs,
                escrow_commitment,
                amount,
            )
            .enqueue(&mut context);

        // transfer tokens to claimant's private balance
        withdraw_tokens(
            &mut context,
            storage.config.read().token,
            context.msg_sender(),
            amount,
        );
    }

    /**
     * Creates a block window for the escrow balance owner to withdraw from their position
     * 
     * @param amount - amount to withdraw from escrow balance
     */
    #[private]
    fn prompt_withdraw_escrow_balance(amount: u128) {
        let escrow_owner = context.msg_sender();
        let mut escrow_owner_note = storage.escrow_owners.at(escrow_owner).get_note().note;
        assert(escrow_owner_note.owner == escrow_owner, "Cannot use escrow owner note");
        storage.escrow_owners.at(escrow_owner).replace(escrow_owner_note).emit(
            encode_and_encrypt_note(&mut context, escrow_owner, escrow_owner),
        );
        let escrow_contract = OpenbankingEscrow::at(context.this_address());
        escrow_contract
            ._prompt_withdraw_escrow_balance(escrow_owner_note.commitment, amount)
            .enqueue(&mut context);
    }

    /**
     * Internal function called from private context that marks an escrow balance for withdrawal by
     * starting a block window
     * 
     * @param commitment - hash computed from user sort code and balance currency code
     * @param amount - amount marked for withdrawal from escrow balance
     */
    #[public]
    #[internal]
    fn _prompt_withdraw_escrow_balance(commitment: Field, amount: u128) {
        // check that commitment doesn't already exist
        let mut escrow_balance = storage.escrow_balances.at(commitment).read();
        escrow_balance.assert_initialized(true);

        escrow_balance.mark_for_withdrawal(amount, context.block_number());
        storage.escrow_balances.at(commitment).write(escrow_balance);
    }

    /**
     * Initiates a withdrawal from an escrow balance
     * 
     * @param amount - amount to be withdrawn from balance
     */
    #[private]
    fn withdraw_escrow_balance(amount: u128) {
        let escrow_owner = context.msg_sender();
        let mut escrow_owner_note = storage.escrow_owners.at(escrow_owner).get_note().note;
        assert(escrow_owner_note.owner == escrow_owner, "Cannot use escrow owner note");
        storage.escrow_owners.at(escrow_owner).replace(escrow_owner_note).emit(
            encode_and_encrypt_note(&mut context, escrow_owner, escrow_owner),
        );

        // decrement escrow balance in escrow
        OpenbankingEscrow::at(context.this_address())
            ._decrement_escrow_balance(escrow_owner_note.commitment, amount)
            .enqueue(&mut context);

        // transfer tokens to escrow owner's private balance
        withdraw_tokens(
            &mut context,
            storage.config.read().token,
            context.msg_sender(),
            amount,
        );
    }

    /**
     * Internal public function function that decrements from an escrow balance mapped to the provided
     * commitment
     * 
     * @param commitment - hash computed from user sort code and balance currency code, mapped to escrow balance
     * @param amount - to decrement from escrow balance
     */
    #[public]
    #[internal]
    fn _decrement_escrow_balance(commitment: Field, amount: u128) {
        // check that escrow exists for the commitment
        let mut escrow_balance = storage.escrow_balances.at(commitment).read();
        escrow_balance.assert_initialized(true);

        // check that amount does not exceed balance and decrement
        // escrow_balance.assert_withdrawable(context.block_number());

        // decrement the escrow balance
        escrow_balance.decrement(amount);

        // update the escrow balance
        storage.escrow_balances.at(commitment).write(escrow_balance);
    }

    /**
     * Internal public function that increments an escrow balance mapped to provided commitment
     * 
     * @param sort_code - commitment mapped to escrow balance
     * @param amount - amount to increase escrow balance by
     */
    #[public]
    #[internal]
    fn _increment_escrow_balance(commitment: Field, amount: u128) {
        // check that escrow exists for the commitment
        let mut escrow_balance = storage.escrow_balances.at(commitment).read();
        escrow_balance.assert_initialized(true);

        // deposit funds into the escrow balance
        escrow_balance.deposit(amount);

        // update the escrow balance
        storage.escrow_balances.at(commitment).write(escrow_balance);
    }

    /**
     * Internal public function initializes the public escrow balance at a specified commitment
     * 
     * @param commitment - hash computed from user sort code and balance currency code, mapped to escrow balance
     * @param amount - intial balance of escrow
     */
    #[public]
    #[internal]
    fn _init_escrow_balance(commitment: Field, amount: u128) {
        // check that commitment doesn't already exist
        let mut escrow_balance = storage.escrow_balances.at(commitment).read();
        escrow_balance.assert_initialized(false);

        // add a new escrow balance
        storage.escrow_balances.at(commitment).write(EscrowBalance::new(amount));
    }

    /**
     * Internal public function that applies an Openbanking payment if the pubkey used is in the pubkey registry and
     * if the commitment exists
     * 
     * @param modulus_limbs - pubkey modulus in limb format
     * @param redc_limbs - reductions params of pubkey in limb format
     * @param commitment - hash computed from user sort code and balance currency code, mapped to escrow balance
     * @param amount - intial balance of escrow
     */
    #[public]
    #[internal]
    fn _apply_payment(
        modulus_limbs: [u128; 18],
        redc_limbs: [u128; 18],
        commitment: Field,
        amount: u128,
    ) {
        // check that hash of pubkey is registered
        let hash = hash_pubkey(modulus_limbs, redc_limbs);
        let stored = storage.pubkey_registry.at(hash).read();
        assert(stored == true, "Pubkey not stored in registry");

        // check that escrow exists for the commitment
        let mut escrow_balance = storage.escrow_balances.at(commitment).read();
        escrow_balance.assert_initialized(true);

        // check that amount does not exceed balance and decremtn
        escrow_balance.decrement(amount);

        // update the escrow balance
        storage.escrow_balances.at(commitment).write(escrow_balance);
    }

    /**
     * Unconstrained function that checks whether an Openbanking payment is valid or not
     * 
     * @param payload - Openbanking.nr payment verfier circuit params in contract friendly format
     * @return - Openbanking.nr payment verfier circuit outputs
     */
    #[utility]
    unconstrained fn check_verify_payload(
        payload: OpenbankingVerifierParamsContract,
    ) -> pub OpenbankingVerifierReturn {
        verify_openbanking_payment(payload.marshal())
    }

    /**
     * Unconstrained function that returns escrow balances matching commitments provided as input
     * 
     * @param commitments - BoundeVec of commitments to match against escrow balances
     * @return - BoundedVec of escrow balances
     */
    #[utility]
    unconstrained fn get_escrow_liqudity_position_page(
        commitments: BoundedVec<Field, MAX_NOTES_PER_PAGE>,
    ) -> pub BoundedVec<EscrowBalance, MAX_NOTES_PER_PAGE> {
        let mut balances = BoundedVec::new();
        for i in 0..MAX_NOTES_PER_PAGE {
            let balance = storage.escrow_balances.at(commitments.get_unchecked(0)).read();
            if i < commitments.len() {
                balances.push(balance);
            }
        }
        balances
    }

    /**
     * Unconstrained function that retrieves an escrow balance
     * 
     * @param commitment - commitment mapped to an escrow balance
     * @return - escrow balance if commitment matches, none if no balance matches commitment
     */
    #[public]
    #[view]
    fn get_escrow_liqudity_position(commitment: Field) -> pub EscrowBalance {
        let balance = storage.escrow_balances.at(commitment).read();
        balance
    }

    /**
     * Unconstrained function that returns escrow owner note that matches scope address
     * 
     * @param scope - address of note owner
     * @return - escrow owner note if note found matching scope, none if not found
     */
    #[utility]
    unconstrained fn get_escrow_owner_note(scope: AztecAddress) -> pub Option<EscrowOwnerNote> {
        if storage.escrow_owners.at(scope).is_initialized() {
            Option::some(storage.escrow_owners.at(scope).view_note())
        } else {
            Option::none()
        }
    }
}
