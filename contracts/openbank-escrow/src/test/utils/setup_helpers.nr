use crate::OpenbankEscrow;
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
        admin: env.create_account(),
        alice: env.create_account(),
        bob: env.create_account(),
    };

    // deploy the token contract
    let usdc_address = deploy_token_contract(&mut env, accounts.admin);

    let escrow_address = deploy_escrow_contract(&mut env, accounts.admin, usdc_address);

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
    let token_contract = env.deploy("./@token_contract", "Token").with_public_void_initializer(
        token_init_call_iface,
    );

    cheatcodes::advance_blocks_by(1);

    token_contract.to_address()
}

pub unconstrained fn deploy_escrow_contract(
    env: &mut TestEnvironment,
    deployer: AztecAddress,
    token_address: AztecAddress,
) -> AztecAddress {
    env.impersonate(deployer);
    let escrow_init_call_iface = OpenbankEscrow::interface().constructor(token_address);
    let escrow_contract = env
        .deploy("./@openbank_escrow", "OpenbankEscrow")
        .with_public_void_initializer(escrow_init_call_iface);
    cheatcodes::advance_blocks_by(1);
    escrow_contract.to_address()
}
