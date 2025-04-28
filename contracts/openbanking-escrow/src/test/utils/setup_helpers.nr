use crate::{
    OpenbankingEscrow,
    test::utils::{
        constants::{REVOLUT_KEY_HASHES, REVOLUT_MODULI, REVOLUT_REDCS},
        escrow_helpers::add_pubkey_hashes,
    },
    utils::hash_pubkey,
};
use aztec::{prelude::AztecAddress, test::helpers::{cheatcodes, test_environment::TestEnvironment}};
use token::Token;

global USDC_NAME: str<31> = "Aztec USDC\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";
global USDC_SYMBOL: str<31> = "USDC.e\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";
global USDC_DECIMALS: u8 = 6;

pub struct TestAccounts {
    admin: AztecAddress,
    alice: AztecAddress,
    bob: AztecAddress,
}

pub struct TestContracts {
    usdc: AztecAddress,
    escrow: AztecAddress,
}

pub unconstrained fn setup() -> (&mut TestEnvironment, TestAccounts, TestContracts) {
    let mut env = TestEnvironment::new();

    // create 4 accounts
    let accounts = TestAccounts {
        admin: env.create_account_contract(1),
        alice: env.create_account_contract(2),
        bob: env.create_account_contract(3),
    };

    // deploy the token contract
    let usdc_address = deploy_token_contract(&mut env, accounts.admin);

    // let escrow_address = deploy_escrow_with_pubkey_hashes(&mut env, accounts.admin, usdc_address);
    let escrow_address =
        deploy_escrow_contract(&mut env, accounts.admin, usdc_address, [0, 0, 0, 0]);

    // return setup params
    (&mut env, accounts, TestContracts { usdc: usdc_address, escrow: escrow_address })
}

pub unconstrained fn deploy_token_contract(
    env: &mut TestEnvironment,
    deployer: AztecAddress,
) -> AztecAddress {
    env.impersonate(deployer);

    let token_init_call_iface =
        Token::interface().constructor(deployer, USDC_NAME, USDC_SYMBOL, USDC_DECIMALS);
    let token_contract =
        env.deploy("./@token", "Token").with_public_void_initializer(token_init_call_iface);

    cheatcodes::advance_blocks_by(1);

    token_contract.to_address()
}

pub unconstrained fn deploy_escrow_contract(
    env: &mut TestEnvironment,
    deployer: AztecAddress,
    token_address: AztecAddress,
    pubkey_hashes: [Field; 4],
) -> AztecAddress {
    env.impersonate(deployer);
    let escrow_init_call_iface =
        OpenbankingEscrow::interface().constructor(token_address, pubkey_hashes);
    let escrow_contract = env
        .deploy("./@openbanking_escrow", "OpenbankingEscrow")
        .with_public_void_initializer(escrow_init_call_iface);
    cheatcodes::advance_blocks_by(1);
    escrow_contract.to_address()
}

pub unconstrained fn deploy_escrow_with_pubkey_hashes(
    env: &mut TestEnvironment,
    deployer: AztecAddress,
    token_address: AztecAddress,
) -> AztecAddress {
    let mut first_batch = [0; 4];
    for i in 0..4 {
        first_batch[i] = REVOLUT_KEY_HASHES[i];
    }
    let escrow_contract = deploy_escrow_contract(env, deployer, token_address, first_batch);
    let second_batch = [REVOLUT_KEY_HASHES[4], 0, 0, 0];
    add_pubkey_hashes(env, deployer, escrow_contract, second_batch);
    escrow_contract
}

pub unconstrained fn get_pubkey_hashes() -> [Field; 5] {
    for i in 0..5 {
        let expected_key_hash = REVOLUT_KEY_HASHES[i];
        let modulus = REVOLUT_MODULI[i];
        let redc = REVOLUT_REDCS[i];
        let computed_key_hashes = hash_pubkey(modulus, redc);
        assert(computed_key_hashes == expected_key_hash, "Expected key hash mismatch");
    }
    REVOLUT_KEY_HASHES
}
