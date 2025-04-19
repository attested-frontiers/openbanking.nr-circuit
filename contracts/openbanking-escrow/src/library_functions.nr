use aztec::{prelude::AztecAddress, context::PrivateContext};
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
    recipient: AztecAddress,
    amount: u128
) {
    let token_contract = Token::at(token);
    let hiding_point_slot = token_contract
        .prepare_private_balance_increase(recipient, recipient)
        .call(context);
    token_contract
        .finalize_transfer_to_private(amount, hiding_point_slot)
        .enqueue(context);
}