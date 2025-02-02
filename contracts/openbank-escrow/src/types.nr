use aztec::protocol_types::traits::Packable;
use std::meta::derive;

pub global PROVIDER_BALANCE_SERIALIZED_LEN: u32 = 2;

struct ProviderBalance {
    balance: U128,
    initialized: bool,
}

impl Packable<PROVIDER_BALANCE_SERIALIZED_LEN> for ProviderBalance {
    fn pack(provider_balance: ProviderBalance) -> [Field; PROVIDER_BALANCE_SERIALIZED_LEN] {
        [provider_balance.balance.to_integer(), provider_balance.initialized as Field]
    }

    fn unpack(fields: [Field; PROVIDER_BALANCE_SERIALIZED_LEN]) -> ProviderBalance {
        ProviderBalance { balance: U128::from_integer(fields[0]), initialized: fields[1] as bool }
    }
}
