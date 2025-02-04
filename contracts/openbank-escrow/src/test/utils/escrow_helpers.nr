use crate::{OpenbankEscrow, types::provider_balance::ProviderBalance};
use authwit::cheatcodes as authwit_cheatcodes;
use aztec::{
    oracle::{execution::{get_block_number, get_contract_address}, storage::storage_read},
    prelude::AztecAddress,
    protocol_types::storage::map::derive_storage_slot_in_map,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
};
use openbanking_verifier::constants::RevolutVerifierParamsContract;
use token::Token;

pub unconstrained fn increment_balance(
    env: &mut TestEnvironment,
    provider: AztecAddress,
    escrow_address: AztecAddress,
    token_address: AztecAddress,
    amount: U128,
) {
    // create token transfer authwit
    let transfer_to_public_call_interface =
        Token::at(token_address).transfer_to_public(provider, escrow_address, amount, 0);

    authwit_cheatcodes::add_private_authwit_from_call_interface(
        provider,
        escrow_address,
        transfer_to_public_call_interface,
    );

    env.impersonate(provider);
    let escrow = OpenbankEscrow::at(escrow_address);
    let _ = escrow.increment_provider_balance(amount).call(&mut env.private());
    cheatcodes::advance_blocks_by(1);
}

pub unconstrained fn initial_deposit(
    env: &mut TestEnvironment,
    provider: AztecAddress,
    escrow_address: AztecAddress,
    token_address: AztecAddress,
    currency_code: Field,
    sort_code: Field,
    amount: U128,
) {
    // create token transfer authwit
    let transfer_to_public_call_interface =
        Token::at(token_address).transfer_to_public(provider, escrow_address, amount, 0);

    authwit_cheatcodes::add_private_authwit_from_call_interface(
        provider,
        escrow_address,
        transfer_to_public_call_interface,
    );

    env.impersonate(provider);
    let escrow = OpenbankEscrow::at(escrow_address);
    // TODO: Add actual randomness
    let randomness: Field = 12345;
    let _ = escrow.init_provider_balance(sort_code, currency_code, amount, randomness).call(
        &mut env.private(),
    );
    cheatcodes::advance_blocks_by(1);
}

pub unconstrained fn prove_payment(
    env: &mut TestEnvironment,
    claimant: AztecAddress,
    escrow_address: AztecAddress,
    payment_params: RevolutVerifierParamsContract,
) {
    env.impersonate(claimant);
    let escrow = OpenbankEscrow::at(escrow_address);
    let _ = escrow.prove_payment_and_claim(payment_params).call(&mut env.private());
    cheatcodes::advance_blocks_by(1);
}

pub unconstrained fn withdraw(
    env: &mut TestEnvironment,
    provider: AztecAddress,
    escrow_address: AztecAddress,
    amount: U128,
) {
    env.impersonate(provider);
    let escrow = OpenbankEscrow::at(escrow_address);
    let _ = escrow.withdraw_provider_balance(amount).call(&mut env.private());
    cheatcodes::advance_blocks_by(1);
}

pub unconstrained fn check_commitment_balance(
    escrow_address: AztecAddress,
    commitment: Field,
    balance: U128,
) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(escrow_address);
    let block_number = get_block_number();

    let balances_slot = OpenbankEscrow::storage_layout().provider_balances.slot;
    let commitment_slot = derive_storage_slot_in_map(balances_slot, commitment);
    let provider: ProviderBalance = storage_read(escrow_address, commitment_slot, block_number);
    assert(balance == provider.balance, "Provider balance not equal to provided balance");
    cheatcodes::set_contract_address(current_contract_address);
}

pub unconstrained fn get_commitment_data(
    escrow_address: AztecAddress,
    commitment: Field,
) -> (U128, Field) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(escrow_address);
    let block_number = get_block_number();

    let balances_slot = OpenbankEscrow::storage_layout().provider_balances.slot;
    let commitment_slot = derive_storage_slot_in_map(balances_slot, commitment);
    let provider: ProviderBalance = storage_read(escrow_address, commitment_slot, block_number);
    cheatcodes::set_contract_address(current_contract_address);
    (provider.balance, provider.withdrawable_at)
}
