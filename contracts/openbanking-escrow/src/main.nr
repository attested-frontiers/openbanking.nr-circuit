use dep::aztec::macros::aztec;

mod constants;
mod library_functions;
mod test;
mod types;
mod utils;

#[aztec]
contract OpenbankingEscrow {

    use crate::{
        types::{
            escrow_balance::EscrowBalance,
            openbanking::OpenbankingVerifierParamsContract,
            escrow_owner_note::EscrowOwnerNote,
            config::Config
        },
        constants::MAX_KEY_HASHES_PER_TX,
        library_functions::withdraw_tokens
    };
    use aztec::{
        oracle::debug_log::debug_log_format,
        encrypted_logs::log_assembly_strategies::default_aes128::note::encode_and_encrypt_note,
        macros::{
            functions::{initializer, internal, private, public, view},
            storage::storage
        },
        prelude::{ AztecAddress, Map, PrivateMutable, PublicImmutable, PublicMutable},
    };
    use openbanking_verifier::{
        io::OpenbankingVerifierReturn,
        verify::verify_openbanking_payment,
    };
    use std::hash::poseidon2::Poseidon2;
    use token::Token;

    #[storage]
    struct Storage<Context> {
        config: PublicImmutable<Config, Context>,
        escrow_owners: Map<AztecAddress, PrivateMutable<EscrowOwnerNote, Context>, Context>,
        escrow_balances: Map<Field, PublicMutable<EscrowBalance, Context>, Context>,
        pubkey_registry: Map<Field, PublicImmutable<bool, Context>, Context>,
    }

    #[public]
    #[initializer]
    fn constructor(token_address: AztecAddress, key_hashes: [Field; MAX_KEY_HASHES_PER_TX]) {
        storage.config.initialize(Config::new(token_address, context.msg_sender()));
        for i in 0..MAX_KEY_HASHES_PER_TX {
            if key_hashes[i] != 0 {
                storage.pubkey_registry.at(key_hashes[i]).initialize(true);
            }
        }
    }

    #[public]
    fn add_key_hashes(key_hashes: [Field; MAX_KEY_HASHES_PER_TX]) {
        let admin = storage.config.read().admin;
        assert(admin == context.msg_sender(), "Only admin can add key hashes");
        for i in 0..MAX_KEY_HASHES_PER_TX {
            if key_hashes[i] != 0 {
                storage.pubkey_registry.at(key_hashes[i]).initialize(true);
            }
        }
    }

    // #[public]
    // fn revoke_key(key_hash: Field) {
    //     let admin = storage.settings.read().admin;
    //     assert(admin == context.msg_sender(), "Only admin can revoke keys");
    //     // todo: should we require the key to be added to remove it? I think no
    //     let revocation_hash = Poseidon2::hash(key_hash, 1);
    //     storage.pubkey_registry.at(revocation_hash).initialize(true);
    //     // todo: can you even tell if a it is initialized? IDT so
    // }

    #[private]
    fn increment_escrow_balance(amount: U128) {
        let escrow_owner = context.msg_sender();
        let escrow_contract = context.this_address();
        // TODO: Perform check that note exists
        let mut escrow_owner_note = storage.escrow_owners.at(escrow_owner).get_note().note;
        assert(escrow_owner_note.owner == escrow_owner, "Cannot use escrow owner note");
        storage.escrow_owner_note.replace(&mut escrow_owner_note).emit(encode_and_encrypt_note(
            &mut context,
            escrow_owner,
            escrow_owner,
        ));
        // transfer private token balance to public balance of escrow
        Token::at(storage.config.read().token)
            .transfer_to_public(escrow_owner, escrow_contract, amount, 0)
            .call(&mut context);

        OpenbankingEscrow::at(escrow_contract)
            ._increment_escrow_balance(escrow_owner_note.commitment, amount)
            .enqueue(&mut context);
    }

    #[private]
    fn init_escrow_balance(
        sort_code: Field,
        currency_code: Field,
        amount: U128,
        randomness: Field,
    ) {
        let escrow_owner = context.msg_sender();
        let escrow_contract = context.this_address();
        // create commitment
        let commitment = Poseidon2::hash([sort_code, currency_code], 2);

        // init escrow owner note
        let mut escrow_owner_note = EscrowOwnerNote::new(commitment, randomness, escrow_owner);

        storage.escrow_owners.at(escrow_owner).initialize(&mut escrow_owner_note).emit(encode_and_encrypt_note(
            &mut context,
            escrow_owner,
            escrow_owner,
        ));

        OpenbankingEscrow::at(escrow_contract)
            ._init_escrow_balance(commitment, amount)
            .enqueue(&mut context);

        // transfer private token balance to public balance of escrow
        let token_contract = storage.config.read().token;
        Token::at(token_contract)
            .transfer_to_public(escrow_owner, escrow_contract, amount, 0)
            .call(&mut context);
    }

    #[private]
    fn prove_payment_and_claim(openbanking_params: OpenbankingVerifierParamsContract) {
        // prove openbanking payment
        let result: OpenbankingVerifierReturn = verify_openbanking_payment(openbanking_params.marshal());

        // escrow commitment retrieved from sort / bank account code and currency
        // todo: add commitment salt
        let escrow_commitment = result.recipient_commitment();

        // parse the amount sent in the open banking transfer
        let amount = U128::from_integer(result.parse_amount());

        // hash payment id and emit as a nullifier
        // should fail if payment id already exists
        let payment_nullifier = result.payment_nullifier();
        context.push_nullifier(payment_nullifier);

        // update public balance
        let escrow_contract = OpenbankingEscrow::at(context.this_address());
        escrow_contract
            ._apply_payment(escrow_commitment, amount)
            .enqueue(&mut context);

        // transfer tokens to claimant's private balance
        withdraw_tokens(
            &mut context,
            storage.config.read().token,
            context.msg_sender(),
            amount,
        );
    }

    #[private]
    fn prompt_withdraw_escrow_balance(amount: U128) {
        let escrow_owner = context.msg_sender();
        let mut escrow_owner_note = storage.escrow_owners.at(escrow_owner).get_note().note;
        assert(escrow_owner_note.owner == escrow_owner, "Cannot use escrow owner note");
        storage.escrow_owners.at(escrow_owner).replace(&mut escrow_owner_note).emit(
            encode_and_encrypt_note(
            &mut context,
            escrow_owner,
            escrow_owner,
        ));
        let escrow_contract = OpenbankingEscrow::at(context.this_address());
        escrow_contract
            ._prompt_withdraw_escrow_balance(escrow_owner_note.commitment, amount)
            .enqueue(&mut context);
    }

    #[public]
    #[internal]
    fn _prompt_withdraw_escrow_balance(commitment: Field, amount: U128) {
        // check that commitment doesn't already exist
        let mut escrow_balance = storage.escrow_balances.at(commitment).read();
        escrow_balance.assert_initialized(true);

        escrow_balance.mark_for_withdrawal(amount, context.block_number());
        storage.escrow_balances.at(commitment).write(escrow_balance);
    }

    #[private]
    fn withdraw_escrow_balance(amount: U128) {
        let escrow_owner = context.msg_sender();
        let mut escrow_owner_note = storage.escrow_owners.at(escrow_owner).get_note().note;
        assert(escrow_owner_note.owner == escrow_owner, "Cannot use escrow owner note");
        storage.escrow_owners.at(escrow_owner).replace(&mut escrow_owner_note).emit(
            encode_and_encrypt_note(
            &mut context,
            escrow_owner,
            escrow_owner,
        ));

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

    #[public]
    #[internal]
    fn _decrement_escrow_balance(commitment: Field, amount: U128) {
        // check that escrow exists for the commitment
        let mut escrow_balance = storage.escrow_balances.at(commitment).read();
        escrow_balance.assert_initialized(true);
        
        // check that amount does not exceed balance and decrement
        escrow_balance.assert_withdrawable(context.block_number());

        // decrement the escrow balance
        escrow_balance.decrement(amount);

        // update the escrow balance
        storage.escrow_balances.at(commitment).write(escrow_balance);
    }

    #[public]
    #[internal]
    fn _increment_escrow_balance(commitment: Field, amount: U128) {
        // check that escrow exists for the commitment
        let mut escrow_balance = storage.escrow_balances.at(commitment).read();
        escrow_balance.assert_initialized(false);

        // deposit funds into the escrow balance
        escrow_balance.deposit(amount);

        // update the escrow balance
        storage.escrow_balances.at(commitment).write(escrow_balance);
    }

    #[public]
    #[internal]
    fn _init_escrow_balance(commitment: Field, amount: U128) {
        // check that commitment doesn't already exist
        let mut escrow_balance = storage.escrow_balances.at(commitment).read();
        escrow_balance.assert_initialized(false);

        // add a new escrow balance
        storage.escrow_balances.at(commitment).write(EscrowBalance::new(amount));
    }

    #[public]
    #[internal]
    fn _apply_payment(commitment: Field, amount: U128) {
        // check that escrow exists for the commitment
        let mut escrow_balance = storage.escrow_balances.at(commitment).read();
        escrow_balance.assert_initialized(true);

        // check that amount does not exceed balance and decremtn
        escrow_balance.decrement(amount);

        // update the escrow balance
        storage.escrow_balances.at(commitment).write(escrow_balance);
    }

    #[public]
    #[view]
    fn get_escrow_liqudity_position(commitment: Field) -> EscrowBalance {
        storage.escrow_balances.at(commitment).read()
    }

    unconstrained fn get_escrow_owner_note(scope: AztecAddress) -> EscrowOwnerNote {
        storage.escrow_owners.at(scope).view_note()
    }
}
