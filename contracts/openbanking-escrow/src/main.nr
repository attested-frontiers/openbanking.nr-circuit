use dep::aztec::macros::aztec;

mod types;
// mod test;
mod utils;

#[aztec]
contract OpenbankingEscrow {

    global MAX_KEY_HASHES_PER_TX: u32 = 4;

    use crate::{
        types::{
            OpenbankingVerifierParamsContract, provider_balance::ProviderBalance,
            provider_note::ProviderNote, settings::Settings
        },
        utils::{bytes_to_num, pack_bytes, hash_pubkey},
    };
    use aztec::{
        encrypted_logs::encrypted_note_emission::encode_and_encrypt_note,
        macros::{functions::{initializer, internal, private, public}, storage::storage},
        prelude::{
            AztecAddress, Map, PrivateMutable, PublicImmutable, PublicMutable,
        },
        protocol_types::utils::field::field_from_bytes,
    };
    use openbanking_verifier::{
        constants::{
            CURRENCY_CODE_VALUE_LENGTH, MAX_AMOUNT_VALUE_LENGTH, OpenbankingVerifierReturn,
            PAYMENT_ID_LENGTH, SORT_CODE_VALUE_LENGTH,
        },
        verify::verify_openbanking_payment,
    };
    use std::hash::poseidon2::Poseidon2;
    use token::Token;

    #[storage]
    struct Storage<Context> {
        provider_account: PrivateMutable<ProviderNote, Context>,
        provider_balances: Map<Field, PublicMutable<ProviderBalance, Context>, Context>,
        spent_payments: Map<Field, PublicMutable<bool, Context>, Context>,
        settings: PublicImmutable<Settings, Context>,
        pubkey_registry: Map<Field, PublicImmutable<bool, Context>, Context>,
    }

    #[public]
    #[initializer]
    fn constructor(token_address: AztecAddress, ) {
        storage.settings.initialize(Settings::new(token_address, context.msg_sender()));
    }

    #[public]
    fn add_key_hashes(key_hashes: [Field; MAX_KEY_HASHES_PER_TX]) {
        let admin = storage.settings.read().admin;
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
    fn increment_provider_balance(amount: U128) {
        // TODO: Perform check that note exists
        let provider_account = storage.provider_account.get_note().note;

        // transfer private token balance to public balance of escrow
        let token_contract = storage.settings.read().token;
        Token::at(token_contract)
            .transfer_to_public(context.msg_sender(), context.this_address(), amount, 0)
            .call(&mut context);

        OpenbankingEscrow::at(context.this_address())
            ._increment_provider_balance(provider_account.commitment, amount)
            .enqueue(&mut context);
    }

    #[private]
    fn init_provider_balance(
        sort_code: Field,
        currency_code: Field,
        amount: U128,
        randomness: Field,
    ) {
        // create commitment
        let commitment = Poseidon2::hash([sort_code, currency_code], 2);

        // init provider note
        let mut provider_note = ProviderNote::new(commitment, randomness, context.msg_sender());

        storage.provider_account.initialize(&mut provider_note).emit(encode_and_encrypt_note(
            &mut context,
            context.msg_sender(),
            context.msg_sender(),
        ));

        OpenbankingEscrow::at(context.this_address())
            ._init_provider_balance(commitment, amount)
            .enqueue(&mut context);

        // transfer private token balance to public balance of escrow
        let token_contract = storage.settings.read().token;
        Token::at(token_contract)
            .transfer_to_public(context.msg_sender(), context.this_address(), amount, 0)
            .call(&mut context);
    }

    #[private]
    fn prove_payment_and_claim(openbanking_params: OpenbankingVerifierParamsContract) {
        // prove openbanking payment
        let OpenbankingVerifierReturn {
    amount,
    currency_code: currency_code_bytes,
    sort_code: sort_code_bytes,
    payment_id,} = verify_openbanking_payment(openbanking_params.marshal());

        // recreate commitment
        let sort_code = field_from_bytes::<SORT_CODE_VALUE_LENGTH>(sort_code_bytes, false);
        let currency_code =
            field_from_bytes::<CURRENCY_CODE_VALUE_LENGTH>(currency_code_bytes, false);
        let commitment = Poseidon2::hash([sort_code, currency_code], 2);

        // parse amount from bounded vec
        let amount = bytes_to_num::<MAX_AMOUNT_VALUE_LENGTH>(amount);

        // hash payment id
        let payment_id_packed = pack_bytes::<PAYMENT_ID_LENGTH>(payment_id);
        let payment_hash = Poseidon2::hash(payment_id_packed, 2);

        // hash the public key
        let public_key_hash = hash_pubkey(
            openbanking_params.modulus_limbs,
            openbanking_params.redc_limbs,
        );
        let valid_key_hash = storage.pubkey_registry.at(public_key_hash).read();
        assert(valid_key_hash == true, "Invalid public key hash.");

        // let revocation_hash = Poseidon2::hash(public_key_hash, 1);
        // todo: check key is not revoked

        // update public balance
        OpenbankingEscrow::at(context.this_address())
            ._apply_payment(payment_hash, commitment, amount)
            .enqueue(&mut context);

        // transfer tokens to claimant's private balance
        OpenbankingEscrow::at(context.this_address())
            ._withdraw_tokens(context.msg_sender(), amount)
            .call(&mut context);
    }

    #[private]
    fn withdraw_provider_balance(amount: U128) {
        // TODO: Perform check that note exists
        // let provider_account = storage.provider_account.get_note().note;

        // decrement provider balance in escrow
        // OpenbankingEscrow::at(context.this_address())
        //     ._decrement_provider_balance(provider_account.commitment, amount)
        //     .enqueue(&mut context);

        // transfer tokens to provider's private balance
        OpenbankingEscrow::at(context.this_address())
            ._withdraw_tokens(context.msg_sender(), amount)
            .call(&mut context);
    }

    #[public]
    #[internal]
    fn _decrement_provider_balance(commitment: Field, amount: U128) {
        let provider_balance = storage.provider_balances.at(commitment).read();
        // assert block number with past withdrawable block restrincton
        let current_block = context.block_number();
        assert(
            current_block as u32 >= provider_balance.withdrawable_at as u32,
            "Cannot withdraw in block restriction window.",
        );
        // assert withdrawable amount doesn't exceed balance
        assert(amount <= provider_balance.balance, "Amount exceeds provider balance.");

        let updated_provider_balance = ProviderBalance {
            balance: provider_balance.balance - amount,
            initialized: provider_balance.initialized,
            withdrawable_at: provider_balance.withdrawable_at,
        };

        storage.provider_balances.at(commitment).write(updated_provider_balance);
    }

    #[public]
    #[internal]
    fn _increment_provider_balance(commitment: Field, amount: U128) {
        let provider_balance = storage.provider_balances.at(commitment).read();

        // get current block number and set withdrawable block to be + 2
        let current_block = context.block_number();
        let updated_provider_balance = ProviderBalance {
            balance: provider_balance.balance + amount,
            initialized: provider_balance.initialized,
            withdrawable_at: current_block + 2,
        };

        storage.provider_balances.at(commitment).write(updated_provider_balance);
    }

    #[public]
    #[internal]
    fn _init_provider_balance(commitment: Field, amount: U128) {
        // check that commitment doesn't already exist
        let provider_balance = storage.provider_balances.at(commitment).read();
        assert(provider_balance.initialized == false, "Commitment has already been set.");

        // get current block number and set withdrawable block to be + 2
        let current_block = context.block_number();
        let updated_provider_balance = ProviderBalance {
            balance: amount,
            initialized: true,
            withdrawable_at: current_block + 2,
        };

        storage.provider_balances.at(commitment).write(updated_provider_balance);
    }

    #[public]
    #[internal]
    fn _apply_payment(payment_hash: Field, commitment: Field, amount: U128) {
        // check that commitment exists
        let provider_balance = storage.provider_balances.at(commitment).read();
        assert(provider_balance.initialized == true, "Commitment does not exist.");

        // check that amount does not exceed balance
        assert(amount <= provider_balance.balance, "Payment amount exceeds provider balance.");

        // check that unique payment hasn't already been stored
        let spent_payment = storage.spent_payments.at(payment_hash).read();
        assert(spent_payment == false, "Payment has already been spent.");

        let updated_balance = ProviderBalance {
            balance: provider_balance.balance - amount,
            initialized: provider_balance.initialized,
            withdrawable_at: provider_balance.withdrawable_at,
        };

        storage.provider_balances.at(commitment).write(updated_balance);
        storage.spent_payments.at(payment_hash).write(true);
    }

    #[private]
    #[internal]
    fn _withdraw_tokens(user: AztecAddress, amount: U128) {
        let token_contract = Token::at(storage.settings.read().token);
        let hiding_point_slot =
            token_contract.prepare_private_balance_increase(user, user).call(&mut context);
        token_contract.finalize_transfer_to_private(amount, hiding_point_slot).enqueue(&mut context);
    }
}
