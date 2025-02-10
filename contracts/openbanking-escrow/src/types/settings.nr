use aztec::protocol_types::{address::AztecAddress, traits::{Serialize, Deserialize, Packable}};

global SETTINGS_LENGTH: u32 = 2;

pub struct Settings {
    token: AztecAddress,
    admin: AztecAddress
}

impl Serialize<SETTINGS_LENGTH> for Settings {
    fn serialize(self: Self) -> [Field; SETTINGS_LENGTH] {
        [self.token.to_field(), self.admin.to_field()]
    }
}

impl Deserialize<SETTINGS_LENGTH> for Settings {
    fn deserialize(fields: [Field; SETTINGS_LENGTH]) -> Self {
        Settings {
            token: AztecAddress::from_field(fields[0]),
            admin: AztecAddress::from_field(fields[1])
        }
    }
}

impl Packable<SETTINGS_LENGTH> for Settings {
    fn pack(self) -> [Field; SETTINGS_LENGTH] {
        self.serialize()
    }

    fn unpack(packed: [Field; SETTINGS_LENGTH]) -> Self {
        Self::deserialize(packed)
    }
}

impl Settings {
    /**
     * Create a settings object
     *
     * @param token - the address of the payment token used
     * @param admin - the address of the admin of the contract
     */
    pub fn new(token: AztecAddress, admin: AztecAddress) -> Self {
        Settings { token, admin }
    }
}