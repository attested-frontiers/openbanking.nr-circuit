use dep::aztec::macros::aztec;

#[aztec]
contract TokenMinter {
    use aztec::{
        macros::{functions::{initializer, private, public}, storage::storage},
        prelude::{AztecAddress, PublicImmutable, PublicMutable},
    };
    use token::Token;

    #[storage]
    struct Storage<Context> {
        admin: PublicImmutable<AztecAddress, Context>,
        token: PublicImmutable<AztecAddress, Context>,
    }

    #[public]
    #[initializer]
    fn constructor() {
        storage.admin.initialize(context.msg_sender());
    }

    #[public]
    fn set_token(token_address: AztecAddress) {
        let admin = storage.admin.read();
        assert(admin == context.msg_sender(), "Sender is not admin");
        storage.token.initialize(token_address);
    }

    #[private]
    fn mint_private(to: AztecAddress, amount: u128) {
        let token = storage.token.read();
        Token::at(token).mint_to_private(to, to, amount).call(&mut context);
    }

    #[public]
    fn mint_public(to: AztecAddress, amount: u128) {
        let token = storage.token.read();
        Token::at(token).mint_to_public(to, amount).call(&mut context);
    }

}