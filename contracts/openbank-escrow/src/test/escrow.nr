use crate::test::utils::{
    escrow_helpers::{check_commitment_balance, initial_deposit, prove_payment},
    revolut_inputs::REVOLUT_PAYMENT_PAYLOAD,
    setup_helpers::setup,
    token_helpers::{check_private_balance, check_public_balance, mint_private, to_usdc_decimals},
};
use dep::aztec::protocol_types::utils::field::field_from_bytes;
use dep::openbanking_verifier::revolut::{CURRENCY_CODE_VALUE_LENGTH, SORT_CODE_VALUE_LENGTH};
use dep::std::hash::poseidon2::Poseidon2;

#[test]
unconstrained fn test_full_flow() {
    let (env, accounts, contracts) = setup();
    let mint_amount = U128::from_integer(to_usdc_decimals(50));

    mint_private(
        env,
        contracts.usdc,
        accounts.admin,
        accounts.alice,
        mint_amount,
    );

    // check that Alice's private balance is mint_amount
    check_private_balance(contracts.usdc, accounts.alice, mint_amount);

    let currency_code = comptime { "GBP".as_bytes() };
    let sort_code = comptime { "04290953215338".as_bytes() };

    let sort_code_field = field_from_bytes::<SORT_CODE_VALUE_LENGTH>(sort_code, false);
    let currency_code_field = field_from_bytes::<CURRENCY_CODE_VALUE_LENGTH>(currency_code, false);

    let commitment = Poseidon2::hash([sort_code_field, currency_code_field], 2);

    initial_deposit(
        env,
        accounts.alice,
        contracts.escrow,
        contracts.usdc,
        currency_code_field,
        sort_code_field,
        mint_amount,
    );

    // check public balance is set in escrow storage and escrow USDC balance
    check_commitment_balance(contracts.escrow, commitment, mint_amount);
    check_public_balance(contracts.usdc, contracts.escrow, mint_amount);

    // prove revolute payment as Bob and claim from escrow
    prove_payment(env, accounts.bob, contracts.escrow, REVOLUT_PAYMENT_PAYLOAD);

    // check that balances have been properly updated
    let new_balance = mint_amount - U128::from_integer(to_usdc_decimals(1));
    check_commitment_balance(contracts.escrow, commitment, new_balance);
    check_public_balance(contracts.usdc, contracts.escrow, new_balance);
    check_private_balance(contracts.usdc, accounts.bob, U128::from_integer(to_usdc_decimals(1)));
}
