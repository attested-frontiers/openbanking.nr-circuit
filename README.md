# A toolkit for verifying Openbanking payments with the Noir language

## Components

### 1. Openbanking Verifier Circuit
---

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

#### Example
```rust
fn main(params: OpenbankingVerifierParams) -> pub OpenbankingVerifierReturn {
    verify_openbanking_payment(params)
}
```

#### Usage
To import into you project you can provider the following line to your Nargo.toml
```
openbanking_verifier = { git = "https://github.com/Mach-34/openbanking-circuit/tree/feat/add-comments", directory = "./lib" }
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
---

Functions as a non-custodial onramp powered through payments using the Openbanking standard

#### Flow
1. Liquidity provider makes a deposit to the escrow contract by calling [`init_escrow_balance`](https://github.com/Mach-34/openbanking-circuit/blob/02be004068aa9548c126934fcfbeb95951c23884/contracts/openbanking-escrow/src/main.nr#L104). They enter their bank account sort code, the currency they wish to accept, and the total amount of USDC tokens they wish to escrow. The bank account sort code and currency code will be hashed together to create a unique commitment that maps to a public balance. This commitment is then stored in the contract's private state for later retrieval by the provider. Additionally the provider's tokens will be transfered from their private balance to the public balance of the escrow

2. When a user wishes to convert their fiat into crypto they would initiate a payment to an escrow provider's bank account (current only uses Revolut). Upon confirmation of a successful payment the server / typescript library to format the inputs to a contract friendly format. When the inputs are ready the user would then call [`prover_payment_and_claim`](https://github.com/Mach-34/openbanking-circuit/blob/ffb4f46fa6e9c3ce21150274f1a92ee9474cf075/contracts/openbanking-escrow/src/main.nr#L172). This would then use the verify_payment circuit from Openbanking verifier library and extract the sort_code, currency_code, payment_id, and amount. The payment_id is used to prevent double spends in the contract, the sort_code and currency_code are hashed together to compute the commitment the liquidity provider has mapped to their balance. The amount extracted from the payment verifier circuit with be decremented from the public escrow balance, and the tokens will be transferred from the escrow contracts's public balance to the payee's private token balance

3. While maintaining an escrow position, the provider may choose to add to their balance at any time by calling [`increment_escrow_balance`](https://github.com/Mach-34/openbanking-circuit/blob/ffb4f46fa6e9c3ce21150274f1a92ee9474cf075/contracts/openbanking-escrow/src/main.nr#L104). A provider may also withdraw from their balance by calling [`withdraw_escrow_balance`](https://github.com/Mach-34/openbanking-circuit/blob/ffb4f46fa6e9c3ce21150274f1a92ee9474cf075/contracts/openbanking-escrow/src/main.nr#L250). There are block restricted withdrawal windows stored with the escrow balance tied to when a provider has last deposited. This prevents foulplay on the part of the provider. An example would be if they attempted to withdraw their funds after a user had sent money to their bank account but had not yet proven the payment on Aztec and claimed their tokens
   

### 3. Typescript Library
---

Typescript library used for generating circuit inputs and exporting utility functions relevant to circuit / contract

#### Installation
```
npm i @openbanking-nr/js-inputs
=================================
yarn add @openbanking-nr/js-inputs 
```

## Related repositories
- Frontend implementation: https://github.com/Mach-34/aztec-openbanking-ui
- Server: https://github.com/openbanking-nr/openbanking.nr-server/tree/main/src
