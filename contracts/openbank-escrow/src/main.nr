use dep::aztec::macros::aztec;

mod types;
mod test;
mod utils;

#[aztec]
contract OpenbankEscrow {

    use crate::{types::ProviderBalance, utils::bytes_to_num};
    use dep::aztec::{
        macros::{functions::{initializer, internal, private, public, view}, storage::storage},
        prelude::{AztecAddress, FunctionSelector, Map, PublicImmutable, PublicMutable},
        protocol_types::utils::field::field_from_bytes,
    };
    use dep::openbanking_verifier::{
        constants::{RevolutVerifierParamsContract, RevolutVerifierReturn},
        revolut::{
            CURRENCY_CODE_VALUE_LENGTH, MAX_AMOUNT_VALUE_LENGTH, SORT_CODE_VALUE_LENGTH,
            verify_revolut,
        },
    };
    use dep::std::hash::poseidon2::Poseidon2;
    use dep::token::Token;

    #[storage]
    struct Storage<Context> {
        provider_balances: Map<Field, PublicMutable<ProviderBalance, Context>, Context>,
        token_contract: PublicImmutable<AztecAddress, Context>,
    }

    #[public]
    #[initializer]
    fn constructor(token_address: AztecAddress) {
        storage.token_contract.initialize(token_address);
    }

    #[private]
    fn increase_provider_balance() {
        // TODO: Must prove ownership of note
    }

    #[private]
    fn init_provider_balance(sort_code: Field, currency_code: Field, amount: U128) {
        // create commitment
        let commitment = Poseidon2::hash([sort_code, currency_code], 2);

        // transfer private token balance to public balance of escrow
        let token_contract = storage.token_contract.read();
        Token::at(token_contract).transfer_to_public(context.msg_sender(), context.this_address(), amount, 0).call(
            &mut context,
        );

        OpenbankEscrow::at(context.this_address())
            ._init_provider_balance(commitment, amount)
            .enqueue(&mut context);

        // TODO: Create note for provider withdrawal
    }

    #[public]
    #[internal]
    fn _init_provider_balance(commitment: Field, amount: U128) {
        // check that commitment doesn't already exist
        let provider = storage.provider_balances.at(commitment).read();
        assert(provider.initialized == false, "Commitment already in use.");

        let provider_balance = ProviderBalance { balance: amount, initialized: true };

        storage.provider_balances.at(commitment).write(provider_balance);
    }

    #[private]
    fn prove_payment_and_claim(revolut_params: RevolutVerifierParamsContract) {
        // prove openbanking payment
        let RevolutVerifierReturn { amount, currency_code: currency_code_bytes, sort_code: sort_code_bytes } =
            verify_revolut(revolut_params.marshal());

        // recreate commitment
        let sort_code = field_from_bytes::<SORT_CODE_VALUE_LENGTH>(sort_code_bytes, false);
        let currency_code =
            field_from_bytes::<CURRENCY_CODE_VALUE_LENGTH>(currency_code_bytes, false);
        let commitment = Poseidon2::hash([sort_code, currency_code], 2);

        // parse amount from bounded vec
        let amount = bytes_to_num::<MAX_AMOUNT_VALUE_LENGTH>(amount);

        // transfer tokens to claimmants private balance
        OpenbankEscrow::at(context.this_address())._claim_tokens(context.msg_sender(), amount).call(
            &mut context,
        );

        // update public balance
        OpenbankEscrow::at(context.this_address())
            ._update_public_escrow_balance(commitment, amount)
            .enqueue(&mut context);
    }

    #[private]
    #[internal]
    fn _claim_tokens(claimmant: AztecAddress, amount: U128) {
        let token_contract = storage.token_contract.read();
        Token::at(token_contract).transfer_to_private(context.msg_sender(), amount);
    }

    #[public]
    #[internal]
    fn _update_public_escrow_balance(commitment: Field, amount: U128) {
        // check that commitment exists
        let provider = storage.provider_balances.at(commitment).read();
        assert(provider.initialized == true, "Commitment does not exist");

        // check that amount does not exceed balance
        assert(amount <= provider.balance, "Amount exceeds balance");

        let provider_balance = ProviderBalance {
            balance: provider.balance - amount,
            initialized: provider.initialized,
        };

        storage.provider_balances.at(commitment).write(provider_balance);
    }
}
