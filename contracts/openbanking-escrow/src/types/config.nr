use aztec::protocol_types::{address::AztecAddress, traits::{Serialize, Deserialize, Packable}};
use std::meta::derive;


#[derive(Serialize, Deserialize, Packable, Eq)]
pub struct Config {
    token: AztecAddress, // Payment token
    admin: AztecAddress // PISP
}

impl Config {
    /**
     * Create a settings object
     *
     * @param token - the address of the payment token used
     * @param admin - the address of the admin of the contract
     */
    pub fn new(token: AztecAddress, admin: AztecAddress) -> Self {
        Config { token, admin }
    }
}