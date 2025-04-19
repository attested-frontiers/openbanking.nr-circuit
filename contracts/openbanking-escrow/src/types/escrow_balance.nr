use aztec::protocol_types::traits::{Serialize, Deserialize, Packable};
use std::meta::derive;

use crate::constants::WITHDRAWAL_LOCKUP_BLOCKS;

pub global ESCROW_BALANCE_SERIALIZED_LEN: u32 = 3;

#[derive(Serialize, Deserialize, Packable, Eq)]
pub struct EscrowBalance {
    balance: u128,
    initialized: bool,
    // block number the escrow owner can withdraw at
    withdrawable_at: Field,
    // amount the escrow owner has prompted to withdraw then
    withdrawable_balance: u128,
}

impl EscrowBalance {

    /**
     * Create a new escrow balance
     *
     * @param balance - initial balance of the escrow position
     */
    pub fn new(balance: u128) -> Self {
        EscrowBalance {
            balance,
            initialized: true,
            withdrawable_at: 0,
            withdrawable_balance: 0,
        }
    }

    /**
     * Ensure the escrow balance struct is initialized or not
     *
     * @param initialized: whether the escrow balance is initialized
     */
    pub fn assert_initialized(self, initialized: bool) {
        assert(self.initialized == initialized, f"Commitment initialization should be {initialized}");
    }

    /**
     * Deposit funds into the escrow balance
     * @param amount: amount to deposit
     */
    pub fn deposit(&mut self, amount: u128) {
        self.balance += amount;
    }

    /**
     * Decrement the escrow balance
     * @dev ONLY USED WHEN EXCHANGING VIA OPENBANKING SIGNATURE
     *
     * @param amount - the amount being decremented from the balance
     */
    pub fn decrement(&mut self, amount: u128) {
        assert(self.balance >= amount, "Amount exceeds escrow balance.");
        self.balance -= amount;
    }

    /**
     * Ensure the balance can be withdrawn from by escrow owner
     *
     * @param amount: amount to withdraw
     * @param block_number: the current block number
     */
    pub fn assert_withdrawable(self, block_number: Field) {
        assert(
            block_number as u32 >= self.withdrawable_at as u32,
            "Cannot withdraw in block restriction window.",
        );
        // assert(
        //     self.withdrawable_at != 0,
        //     "Escrow has not been prompted for withdrawal by owner"
        // );
        // assert withdrawable amount doesn't exceed balance
        // assert(self.withdrawable_balance <= self.balance, "Amount exceeds escrow balance.");
    }

    /**
     * Mark the escrow balance for withdrawal
     * @dev can be overwritten if bad withdrawal request already made
     *
     * @param amount - the amount of funds to withdraw from the escrow
     * @param
     */
    pub fn mark_for_withdrawal(&mut self, amount: u128, block_number: Field) {
        assert(self.balance >= amount, "Amount to withdraw exceeds escrow balance");
        self.withdrawable_at = block_number + WITHDRAWAL_LOCKUP_BLOCKS as Field;
        self.withdrawable_balance = amount;
    }

    /**
     * Complete the record keeping of the withdrawal
     *
     * @return the amount withdrawn
     */
    pub fn complete_withdraw(&mut self) -> u128 {
        let amount_to_withdraw = self.withdrawable_balance;
        self.balance -= amount_to_withdraw;
        self.withdrawable_at = 0;
        self.withdrawable_balance = 0;
        amount_to_withdraw
    }
}