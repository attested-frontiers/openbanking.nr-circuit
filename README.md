# A toolkit for verifying Openbanking payments with the Noir language

## Components

### 1. Openbanking Verifier Circuit

Circuit used for verifying payments using the Openbanking standard
 - Verifies PS256 signature over the payment payload
 - Extracts, creditor sort code, payment id, currency code, and currency amount

#### Inputs (OpenbankingVerifierParams)
 - `signature_limbs` - signature over Openbanking payment in limb format
 - `modulus_limbs` - modulus of pubkey used to verify signature over payment in limb format
 - `redc_limbs` - reduction parameters of pubkey used to verify signature over payment in limb format
 - `partial_hash_start` - partial hash of the JWT header used to reduce constraints
 - `header_delimiter_index` - index of delimiter "." between JWT header and payment JSON payload in `payload` parameter
 - `payload` - payment payload of the form <jwt_header>.<json_payload>

#### Outputs (OpenbankingVerifierReturn)
 - `amount` - payment currency amount
 - `currency_code` - three letter code of the currency type (ex: GBP)
 - `payment_id` - unqiue ID of payment, useful when preventing double spends
- `sort_code` - sort code of creditor account

#### Usage
```rust
fn main(params: OpenbankingVerifierParams) -> pub OpenbankingVerifierReturn {
    verify_openbanking_payment(params)
}
```

#### Run test from CLI

1. Simply run `nargo test` in the root directory 

#### Run circuit from JS

1. Compile circuit
```
cd ./scripts && ./compile.sh
```

2. Navigate to JS directory
```
cd ../js/src
```

3. Run JS code and view logged witness
```
node index.js
```

### 2. Openbanking Escrow Contract

Functions as a non-custodial onramp powered through payments using the Openbanking standard

#### Flow
1. Liquidity provider makes a deposit to the escrow contract by calling [init_escrow_balance](https://github.com/Mach-34/openbanking-circuit/blob/02be004068aa9548c126934fcfbeb95951c23884/contracts/openbanking-escrow/src/main.nr#L104). They enter their bank account sort code, the currency they wish to accept, and the total amount of USDC tokens they wish to escrow. The bank account sort code and currency code will be hashed together to create a unique commitment that maps to a public balance. This commitment is then stored in the contract's private state for later retrieval by the provider 

2. When a user wishes to 
   

### 3. Typescript Library
Typescript library used for generating circuit inputs and exporting utility functions relevant to circuit / contract

#### Installation
```
npm i @openbanking-nr/js-inputs
=================================
yarn add @openbanking-nr/js-inputs 
```

## Related repositories
- Frontend: 
