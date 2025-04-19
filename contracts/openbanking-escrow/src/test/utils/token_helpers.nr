use crate::test::utils::setup_helpers::USDC_DECIMALS;
use dep::token::Token;
use aztec::{
    oracle::{execution::{get_block_number, get_contract_address}, storage::storage_read},
    prelude::AztecAddress,
    protocol_types::storage::map::derive_storage_slot_in_map,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
};

pub unconstrained fn to_usdc_decimals(amount: u128) -> u128 {
    amount * 10.pow_32(USDC_DECIMALS as Field) as u128
}

pub unconstrained fn mint_private(
    env: &mut TestEnvironment,
    token_address: AztecAddress,
    minter: AztecAddress,
    recipient: AztecAddress,
    amount: u128,
) {
    env.impersonate(minter);
    let _ = Token::at(token_address).mint_to_private(minter, recipient, amount).call(
        &mut env.private(),
    );
    cheatcodes::advance_blocks_by(1);
}

pub unconstrained fn mint_public(
    env: &mut TestEnvironment,
    token_address: AztecAddress,
    minter: AztecAddress,
    recipient: AztecAddress,
    amount: u128,
) {
    env.impersonate(minter);
    let _ = Token::at(token_address).mint_to_public(recipient, amount).call(&mut env.public());
    cheatcodes::advance_blocks_by(1);
}

pub unconstrained fn check_public_balance(
    token_contract_address: AztecAddress,
    address: AztecAddress,
    address_amount: u128,
) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(token_contract_address);
    let block_number = get_block_number();

    let balances_slot = Token::storage_layout().public_balances.slot;
    let address_slot = derive_storage_slot_in_map(balances_slot, address);
    let amount: u128 = storage_read(token_contract_address, address_slot, block_number);
    assert(amount == address_amount, "Public balance is not correct");
    cheatcodes::set_contract_address(current_contract_address);
}

pub unconstrained fn check_private_balance(
    token_contract_address: AztecAddress,
    address: AztecAddress,
    address_amount: u128,
) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(token_contract_address);
    // Direct call to unconstrained
    let balance_of_private = Token::balance_of_private(address);
    assert(balance_of_private == address_amount, "Private balance is not correct");
    cheatcodes::set_contract_address(current_contract_address);
}
