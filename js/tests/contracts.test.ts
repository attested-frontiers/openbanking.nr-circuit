import { AccountWalletWithSecretKey, AztecAddress, createPXEClient, Fr, PXE, SponsoredFeePaymentMethod } from "@aztec/aztec.js";
import { getDeployedTestAccountsWallets } from '@aztec/accounts/testing';
import { OpenbankingEscrowContract, TokenContract, TokenMinterContract } from '../src/artifacts';
import { deployEscrowContract, deployTokenContract } from '../src/deploy/helpers';
import { getSponsoredFPCInstance } from "../src/utils.js";
import inputs from './test_data/inputs.json'


const PXE_URL = "http://localhost:8080"

describe('OpenBanking.nr Contract Test', () => {

    let admin: AccountWalletWithSecretKey;
    let alice: AccountWalletWithSecretKey;
    let bob: AccountWalletWithSecretKey;
    let escrow: OpenbankingEscrowContract;
    let fpc: SponsoredFeePaymentMethod;
    let pxe: PXE;
    let token: TokenContract;
    let tokenMinter: TokenMinterContract;

    beforeAll(async () => {
        pxe = createPXEClient(PXE_URL);
        [admin, alice, bob] = await getDeployedTestAccountsWallets(pxe);
        const sponsoredFPC = await getSponsoredFPCInstance();
        fpc = new SponsoredFeePaymentMethod(sponsoredFPC.address);
        token = await deployTokenContract(admin, admin.getAddress(), fpc);
        escrow = await deployEscrowContract(admin, fpc, token.address);
    })

    describe("Test escrow contract deposit", () => {
        it("Should update public balance and transfer tokens from depositor", async () => {

            // mint 10,000 USDC to alice
            const mintAmt = 10000n * (10n ** 6n);
            const depositAmt = mintAmt / 5n;
            await token.methods.mint_to_private(admin.getAddress(), alice.getAddress(), mintAmt).send().wait();
            await token.methods.mint_to_public(alice.getAddress(), mintAmt).send().wait();

            // create input params
            const sortcodeField = Fr.fromBufferReduce(
                Buffer.from('04290953215338').reverse()
            );
            const currencyCodeField = Fr.fromBufferReduce(
                Buffer.from('GBP').reverse()
            );

            // create auth witness so escrow can trasfer from private balance to public
            const action = token.methods
                .transfer_private_to_public(
                    alice.getAddress(),
                    escrow.address,
                    depositAmt,
                    0
                );

            const witness = await alice.createAuthWit({ caller: escrow.address, action })


            // create new escrow position
            await escrow.withWallet(alice)
                .methods
                .init_escrow_balance(sortcodeField, currencyCodeField, depositAmt, Fr.random())
                .send({ authWitnesses: [witness] })
                .wait();

            // get fetch new private balance of alice and public balance of escrow
            const aliceBalPriv = await token.methods.balance_of_private(alice.getAddress()).simulate();
            const escrowBalPub = await token.methods.balance_of_public(escrow.address).simulate();


            // transform inputs to contract friendly format
            const contractInputs = {
                redc_limbs: inputs.inputs.redc_limbs.map(limb => Fr.fromHexString(limb).toBigInt()),
                modulus_limbs: inputs.inputs.modulus_limbs.map(limb => Fr.fromHexString(limb).toBigInt()),
                signature_limbs: inputs.inputs.signature_limbs.map(limb => Fr.fromHexString(limb).toBigInt()),
                header_delimiter_index: inputs.inputs.header_delimiter_index,
                partial_hash_start: inputs.inputs.partial_hash_start,
                payload: inputs.inputs.payload.storage.map(val => Number(val)),
                payload_length: Number(inputs.inputs.payload.len)
            }

            // prove payment
            await escrow.methods.prove_payment_and_claim(contractInputs).send().wait();
        });
    });

});