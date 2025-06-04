use aztec::{context::PrivateContext, prelude::AztecAddress};
use token::Token;

/**
 * Prompts a public-> private transfer from escrow to the recipient
 *
 * @param context - the private execution context
 * @param token - the token contract address
 * @param recipient - the recipient of the funds
 * @param amount - the amount to withdraw
 */
#[contract_library_method]
pub fn withdraw_tokens(
    context: &mut PrivateContext,
    token: AztecAddress,
    escrow: AztecAddress,
    recipient: AztecAddress,
    amount: u128,
) {
    let token_contract = Token::at(token);
    token_contract.transfer_public_to_private(escrow, recipient, amount, 0).call(context);
}
