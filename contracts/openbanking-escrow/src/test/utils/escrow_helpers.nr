use crate::{
    OpenbankingEscrow,
    types::{escrow_balance::EscrowBalance, openbanking::OpenbankingVerifierParamsContract},
};
use authwit::cheatcodes as authwit_cheatcodes;
use aztec::{
    oracle::{
        execution::{get_block_number, get_contract_address},
        random::random,
        storage::storage_read,
    },
    prelude::AztecAddress,
    protocol_types::storage::map::derive_storage_slot_in_map,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
};
use token::Token;

pub unconstrained fn add_pubkey_hashes(
    env: &mut TestEnvironment,
    admin: AztecAddress,
    escrow_address: AztecAddress,
    pubkey_hashes: [Field; 4],
) {
    env.impersonate(admin);
    let escrow = OpenbankingEscrow::at(escrow_address);
    let _ = escrow.add_key_hashes(pubkey_hashes).call(&mut env.public());
    cheatcodes::advance_blocks_by(1);
}

pub unconstrained fn revoke_pubkey_hashes(
    env: &mut TestEnvironment,
    admin: AztecAddress,
    escrow_address: AztecAddress,
    pubkey_hashes: [Field; 4],
) {
    env.impersonate(admin);
    let escrow = OpenbankingEscrow::at(escrow_address);
    let _ = escrow.revoke_keys(pubkey_hashes).call(&mut env.public());
    cheatcodes::advance_blocks_by(1);
}

pub unconstrained fn check_pubkey_hash_initialized(
    escrow_address: AztecAddress,
    hash: Field,
) -> bool {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(escrow_address);
    let block_number = get_block_number();

    let balances_slot = OpenbankingEscrow::storage_layout().pubkey_registry.slot;
    let pubkey_hash_slot = derive_storage_slot_in_map(balances_slot, hash);
    let pubkey_hash_initialized: bool =
        storage_read(escrow_address, pubkey_hash_slot, block_number);
    cheatcodes::set_contract_address(current_contract_address);
    pubkey_hash_initialized
}

pub unconstrained fn increment_balance(
    env: &mut TestEnvironment,
    escrow_owner: AztecAddress,
    escrow_address: AztecAddress,
    token_address: AztecAddress,
    amount: u128,
) {
    // create token transfer authwit
    let transfer_to_public_call_interface =
        Token::at(token_address).transfer_to_public(escrow_owner, escrow_address, amount, 0);

    authwit_cheatcodes::add_private_authwit_from_call_interface(
        escrow_owner,
        escrow_address,
        transfer_to_public_call_interface,
    );

    env.impersonate(escrow_owner);
    let escrow = OpenbankingEscrow::at(escrow_address);
    let _ = escrow.increment_escrow_balance(amount).call(&mut env.private());
    cheatcodes::advance_blocks_by(1);
}

pub unconstrained fn initial_deposit(
    env: &mut TestEnvironment,
    escrow_owner: AztecAddress,
    escrow_address: AztecAddress,
    token_address: AztecAddress,
    currency_code: Field,
    sort_code: Field,
    amount: u128,
) {
    // create token transfer authwit
    let transfer_to_public_call_interface =
        Token::at(token_address).transfer_to_public(escrow_owner, escrow_address, amount, 0);

    authwit_cheatcodes::add_private_authwit_from_call_interface(
        escrow_owner,
        escrow_address,
        transfer_to_public_call_interface,
    );

    env.impersonate(escrow_owner);
    let escrow = OpenbankingEscrow::at(escrow_address);
    // TODO: Add actual randomness
    let randomness = unsafe { random() };
    let _ = escrow.init_escrow_balance(sort_code, currency_code, amount, randomness).call(
        &mut env.private(),
    );
    cheatcodes::advance_blocks_by(1);
}

pub unconstrained fn prove_payment(
    env: &mut TestEnvironment,
    claimant: AztecAddress,
    escrow_address: AztecAddress,
    payment_params: OpenbankingVerifierParamsContract,
) {
    env.impersonate(claimant);
    let escrow = OpenbankingEscrow::at(escrow_address);
    let _ = escrow.prove_payment_and_claim(payment_params).call(&mut env.private());
    cheatcodes::advance_blocks_by(1);
}

pub unconstrained fn prompt_withdrawal(
    env: &mut TestEnvironment,
    escrow_owner: AztecAddress,
    escrow_address: AztecAddress,
    amount: u128,
    advance: bool,
) {
    env.impersonate(escrow_owner);
    let escrow = OpenbankingEscrow::at(escrow_address);
    let _ = escrow.prompt_withdraw_escrow_balance(amount).call(&mut env.private());
    let mut blocks_to_advance = 1;
    if advance {
        blocks_to_advance += 1;
    }
    cheatcodes::advance_blocks_by(blocks_to_advance);
}

pub unconstrained fn withdraw(
    env: &mut TestEnvironment,
    escrow_owner: AztecAddress,
    escrow_address: AztecAddress,
    amount: u128,
) {
    env.impersonate(escrow_owner);
    let escrow = OpenbankingEscrow::at(escrow_address);
    let _ = escrow.withdraw_escrow_balance(amount).call(&mut env.private());
    cheatcodes::advance_blocks_by(1);
}

pub unconstrained fn check_commitment_balance(
    escrow_address: AztecAddress,
    commitment: Field,
    balance: u128,
) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(escrow_address);
    let block_number = get_block_number();

    let balances_slot = OpenbankingEscrow::storage_layout().escrow_balances.slot;
    let commitment_slot = derive_storage_slot_in_map(balances_slot, commitment);
    let escrow_balance: EscrowBalance = storage_read(escrow_address, commitment_slot, block_number);
    assert(balance == escrow_balance.balance, "Provider balance not equal to provided balance");
    cheatcodes::set_contract_address(current_contract_address);
}

pub unconstrained fn get_commitment_data(
    escrow_address: AztecAddress,
    commitment: Field,
) -> (u128, Field) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(escrow_address);
    let block_number = get_block_number();

    let balances_slot = OpenbankingEscrow::storage_layout().escrow_balances.slot;
    let commitment_slot = derive_storage_slot_in_map(balances_slot, commitment);
    let escrow_balance: EscrowBalance = storage_read(escrow_address, commitment_slot, block_number);
    cheatcodes::set_contract_address(current_contract_address);
    (escrow_balance.balance, escrow_balance.withdrawable_at)
}
