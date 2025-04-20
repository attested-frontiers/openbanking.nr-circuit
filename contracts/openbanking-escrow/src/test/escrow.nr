use crate::test::utils::{
    escrow_helpers::{
        add_pubkey_hashes, check_commitment_balance, check_pubkey_hash_initialized,
        get_commitment_data, increment_balance, initial_deposit, prompt_withdrawal, prove_payment,
        revoke_pubkey_hashes, withdraw,
    },
    setup_helpers::{get_pubkey_hashes, setup},
    test_inputs::{CURRENCY_CODE, REVOLUT_PAYMENT_PAYLOAD, SORT_CODE},
    token_helpers::{check_private_balance, check_public_balance, mint_private, to_usdc_decimals},
};
use crate::utils::hash_pubkey;
use dep::aztec::{
    oracle::execution::get_block_number, protocol_types::utils::field::field_from_bytes,
    test::helpers::cheatcodes,
};
use dep::openbanking_verifier::constants::{CURRENCY_CODE_VALUE_LENGTH, SORT_CODE_VALUE_LENGTH};
use dep::std::hash::poseidon2::Poseidon2;

// #[test]
unconstrained fn test_admin_key_additon_revocation() {
    let (env, accounts, contracts) = setup();

    // add pubkey
    add_pubkey_hashes(env, accounts.admin, contracts.escrow, [1, 0, 0, 0]);
    let is_initialized = check_pubkey_hash_initialized(contracts.escrow, 1);
    assert(is_initialized == true);

    // revoke pubkey
    revoke_pubkey_hashes(env, accounts.admin, contracts.escrow, [1, 0, 0, 0]);
    let is_revoked = check_pubkey_hash_initialized(contracts.escrow, 1);
    assert(is_revoked == false);

    let pubkey_hashes = get_pubkey_hashes();
}

// #[test(should_fail_with = "Pubkey not stored in registry")]
unconstrained fn test_claim_with_invalid_pubkey() {
    let (env, accounts, contracts) = setup();
    let mint_amount = to_usdc_decimals(50);

    // remove public key
    revoke_pubkey_hashes(
        env,
        accounts.admin,
        contracts.escrow,
        [0x03d5fde00c9d82e7d073d1b0552ba3fe3f734ea82caa215fd4a3a882919c557b, 0, 0, 0],
    );

    mint_private(
        env,
        contracts.usdc,
        accounts.admin,
        accounts.alice,
        mint_amount,
    );

    // check that Alice's private balance is mint_amount
    check_private_balance(contracts.usdc, accounts.alice, mint_amount);

    let sort_code_field = field_from_bytes::<SORT_CODE_VALUE_LENGTH>(SORT_CODE, false);
    let currency_code_field = field_from_bytes::<CURRENCY_CODE_VALUE_LENGTH>(CURRENCY_CODE, false);

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
}

// #[test]
unconstrained fn test_claim_revolut() {
    let (env, accounts, contracts) = setup();
    let mint_amount = to_usdc_decimals(50);

    // ensure pubkey is added
    add_pubkey_hashes(
        env,
        accounts.admin,
        contracts.escrow,
        [0x03d5fde00c9d82e7d073d1b0552ba3fe3f734ea82caa215fd4a3a882919c557b, 0, 0, 0],
    );

    mint_private(
        env,
        contracts.usdc,
        accounts.admin,
        accounts.alice,
        mint_amount,
    );

    // check that Alice's private balance is mint_amount
    check_private_balance(contracts.usdc, accounts.alice, mint_amount);

    let sort_code_field = field_from_bytes::<SORT_CODE_VALUE_LENGTH>(SORT_CODE, false);
    let currency_code_field = field_from_bytes::<CURRENCY_CODE_VALUE_LENGTH>(CURRENCY_CODE, false);

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
    let new_balance = mint_amount - to_usdc_decimals(1);
    check_commitment_balance(contracts.escrow, commitment, new_balance);
    check_public_balance(contracts.usdc, contracts.escrow, new_balance);
    check_private_balance(contracts.usdc, accounts.bob, to_usdc_decimals(1));
    let key_hashes = get_pubkey_hashes();
}

// #[test(should_fail_with = "Cannot withdraw in block restriction window.")]
unconstrained fn test_early_withdraw() {
    let (env, accounts, contracts) = setup();
    let mint_amount = to_usdc_decimals(50);

    mint_private(
        env,
        contracts.usdc,
        accounts.admin,
        accounts.alice,
        mint_amount,
    );

    let sort_code_field = field_from_bytes::<SORT_CODE_VALUE_LENGTH>(SORT_CODE, false);
    let currency_code_field = field_from_bytes::<CURRENCY_CODE_VALUE_LENGTH>(CURRENCY_CODE, false);

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

    // attempt early withdrawl
    withdraw(env, accounts.alice, contracts.escrow, 50);
}

// TODO: Check why tokens are not trasferred to escrow owner
// #[test]
unconstrained fn test_successful_withdrawal() {
    let (env, accounts, contracts) = setup();
    let mint_amount = to_usdc_decimals(50);

    mint_private(
        env,
        contracts.usdc,
        accounts.admin,
        accounts.alice,
        mint_amount,
    );

    let sort_code_field = field_from_bytes::<SORT_CODE_VALUE_LENGTH>(SORT_CODE, false);
    let currency_code_field = field_from_bytes::<CURRENCY_CODE_VALUE_LENGTH>(CURRENCY_CODE, false);

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

    // prompt withdrawal
    prompt_withdrawal(env, accounts.alice, contracts.escrow, mint_amount, true);
    // withdraw
    withdraw(env, accounts.alice, contracts.escrow, mint_amount);

    // check_commitment_balance(contracts.escrow, commitment, 0);
    // check_public_balance(contracts.usdc, contracts.escrow, 0);
    // check_private_balance(contracts.usdc, accounts.alice, mint_amount);
}

// #[test(should_fail_with = "Amount exceeds escrow balance.")]
unconstrained fn test_withdrawal_amount_exceeds_balance() {
    let (env, accounts, contracts) = setup();
    let mint_amount = to_usdc_decimals(50);

    mint_private(
        env,
        contracts.usdc,
        accounts.admin,
        accounts.alice,
        mint_amount,
    );

    let sort_code_field = field_from_bytes::<SORT_CODE_VALUE_LENGTH>(SORT_CODE, false);
    let currency_code_field = field_from_bytes::<CURRENCY_CODE_VALUE_LENGTH>(CURRENCY_CODE, false);

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

    // advance block by 1 to withdraw (withdrawal restriction is 2 and we already advance by one in intial deposit helper)
    cheatcodes::advance_blocks_by(1);

    withdraw(
        env,
        accounts.alice,
        contracts.escrow,
        mint_amount + to_usdc_decimals(10),
    );
}

// #[test]
unconstrained fn test_increment_escrow_balance() {
    let (env, accounts, contracts) = setup();
    let mint_amount = to_usdc_decimals(70);
    let increment_amount = to_usdc_decimals(20);

    mint_private(
        env,
        contracts.usdc,
        accounts.admin,
        accounts.alice,
        mint_amount,
    );

    let sort_code_field = field_from_bytes::<SORT_CODE_VALUE_LENGTH>(SORT_CODE, false);
    let currency_code_field = field_from_bytes::<CURRENCY_CODE_VALUE_LENGTH>(CURRENCY_CODE, false);

    let commitment = Poseidon2::hash([sort_code_field, currency_code_field], 2);

    initial_deposit(
        env,
        accounts.alice,
        contracts.escrow,
        contracts.usdc,
        currency_code_field,
        sort_code_field,
        mint_amount - increment_amount,
    );

    // increment balance
    increment_balance(
        env,
        accounts.alice,
        contracts.escrow,
        contracts.usdc,
        increment_amount,
    );

    let (balance, withdrawable_at) = get_commitment_data(contracts.escrow, commitment);

    let block_number = get_block_number();
    assert(mint_amount == balance);
    assert(withdrawable_at == block_number as Field + 1);
}

// #[test(should_fail_with = "Rejecting tx for emitting duplicate nullifiers")]
unconstrained fn test_init_escrow_twice() {
    let (env, accounts, contracts) = setup();
    let mint_amount = to_usdc_decimals(50);

    mint_private(
        env,
        contracts.usdc,
        accounts.admin,
        accounts.alice,
        mint_amount,
    );

    let sort_code_field = field_from_bytes::<SORT_CODE_VALUE_LENGTH>(SORT_CODE, false);
    let currency_code_field = field_from_bytes::<CURRENCY_CODE_VALUE_LENGTH>(CURRENCY_CODE, false);

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

    // try second initial deposit
    initial_deposit(
        env,
        accounts.alice,
        contracts.escrow,
        contracts.usdc,
        currency_code_field,
        sort_code_field,
        mint_amount,
    );
}

// TODO: Check for multiple PXE cheatcode
// #[test(should_fail_with = "Commitment has already been set.")]
// unconstrained fn test_commitment_already_set() {
//     let (env, accounts, contracts) = setup();
//     let mint_amount_alice = U128::from_integer(to_usdc_decimals(50));
//     let mint_amount_bob = U128::from_integer(to_usdc_decimals(25));

//     // mint private Alice
//     mint_private(
//         env,
//         contracts.usdc,
//         accounts.admin,
//         accounts.alice,
//         mint_amount_alice,
//     );

//     // mint private Bob
//     mint_private(
//         env,
//         contracts.usdc,
//         accounts.admin,
//         accounts.alice,
//         mint_amount_alice,
//     );

//     let sort_code_field = field_from_bytes::<SORT_CODE_VALUE_LENGTH>(SORT_CODE, false);
//     let currency_code_field = field_from_bytes::<CURRENCY_CODE_VALUE_LENGTH>(CURRENCY_CODE, false);

//     let commitment = Poseidon2::hash([sort_code_field, currency_code_field], 2);

//     // intial deposit Alice
//     initial_deposit(
//         env,
//         accounts.alice,
//         contracts.escrow,
//         contracts.usdc,
//         currency_code_field,
//         sort_code_field,
//         mint_amount_alice,
//     );

//     // intial deposit Bob
//     initial_deposit(
//         env,
//         accounts.bob,
//         contracts.escrow,
//         contracts.usdc,
//         currency_code_field,
//         sort_code_field,
//         mint_amount_bob,
//     );
// }

// #[test(should_fail_with = "Assertion failed: Commitment initialization should be true 'self.initialized == initialized'")]
unconstrained fn test_claim_on_nonexistent_commitment() {
    let (env, accounts, contracts) = setup();

    add_pubkey_hashes(
        env,
        accounts.admin,
        contracts.escrow,
        [0x03d5fde00c9d82e7d073d1b0552ba3fe3f734ea82caa215fd4a3a882919c557b, 0, 0, 0],
    );

    let sort_code_field = field_from_bytes::<SORT_CODE_VALUE_LENGTH>(SORT_CODE, false);
    let currency_code_field = field_from_bytes::<CURRENCY_CODE_VALUE_LENGTH>(CURRENCY_CODE, false);

    let commitment = Poseidon2::hash([sort_code_field, currency_code_field], 2);

    prove_payment(env, accounts.bob, contracts.escrow, REVOLUT_PAYMENT_PAYLOAD);
}

// #[test(should_fail_with = "Assertion failed: Amount exceeds escrow balance. 'self.balance >= amount'")]
unconstrained fn test_payment_amount_exceeds_escrow_balance() {
    let (env, accounts, contracts) = setup();
    let mint_amount = to_usdc_decimals(1) / 10;

    // ensure pubkey is added
    add_pubkey_hashes(
        env,
        accounts.admin,
        contracts.escrow,
        [0x03d5fde00c9d82e7d073d1b0552ba3fe3f734ea82caa215fd4a3a882919c557b, 0, 0, 0],
    );

    mint_private(
        env,
        contracts.usdc,
        accounts.admin,
        accounts.alice,
        mint_amount,
    );

    let sort_code_field = field_from_bytes::<SORT_CODE_VALUE_LENGTH>(SORT_CODE, false);
    let currency_code_field = field_from_bytes::<CURRENCY_CODE_VALUE_LENGTH>(CURRENCY_CODE, false);

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

    // prove payment with amount that exceeds escrow owner balance
    prove_payment(env, accounts.bob, contracts.escrow, REVOLUT_PAYMENT_PAYLOAD);
}

// #[test(should_fail_with = "Payment has already been spent.")]
unconstrained fn test_double_spend() {
    let (env, accounts, contracts) = setup();
    let mint_amount = to_usdc_decimals(50);

    // ensure pubkey is added
    add_pubkey_hashes(
        env,
        accounts.admin,
        contracts.escrow,
        [0x03d5fde00c9d82e7d073d1b0552ba3fe3f734ea82caa215fd4a3a882919c557b, 0, 0, 0],
    );

    mint_private(
        env,
        contracts.usdc,
        accounts.admin,
        accounts.alice,
        mint_amount,
    );

    let sort_code_field = field_from_bytes::<SORT_CODE_VALUE_LENGTH>(SORT_CODE, false);
    let currency_code_field = field_from_bytes::<CURRENCY_CODE_VALUE_LENGTH>(CURRENCY_CODE, false);

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

    prove_payment(env, accounts.bob, contracts.escrow, REVOLUT_PAYMENT_PAYLOAD);

    // attempt to prove same payment
    prove_payment(env, accounts.bob, contracts.escrow, REVOLUT_PAYMENT_PAYLOAD);
}
