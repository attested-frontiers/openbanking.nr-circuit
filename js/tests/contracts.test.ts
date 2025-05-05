import { AccountWalletWithSecretKey, AztecAddress, createPXEClient, Fr, PXE, SponsoredFeePaymentMethod } from "@aztec/aztec.js";
import { getDeployedTestAccountsWallets } from '@aztec/accounts/testing';
import { OpenbankingEscrowContract } from '../src/artifacts';
import { deployEscrowContract, deployTokenContract, getDeployedSponsoredFPCAddress } from '../src/deploy/helpers';
import { TokenContract } from '@aztec/noir-contracts.js/Token';


const PXE_URL = "http://localhost:8080"

describe('OpenBanking.nr Contract Test', () => {

    let admin: AccountWalletWithSecretKey;
    let alice: AccountWalletWithSecretKey;
    let bob: AccountWalletWithSecretKey;
    let escrow: OpenbankingEscrowContract;
    let fpc: SponsoredFeePaymentMethod;
    let pxe: PXE;
    let token: TokenContract;

    beforeAll(async () => {
        pxe = createPXEClient(PXE_URL);
        [admin, alice, bob] = await getDeployedTestAccountsWallets(pxe);
        fpc = new SponsoredFeePaymentMethod(await getDeployedSponsoredFPCAddress(pxe));
        token = await deployTokenContract(admin, fpc);
        escrow = await deployEscrowContract(admin, fpc, token);
    })

    describe("Test escrow contract deposit", () => {
        it("Should update public balance and transfer tokens from depositor", async () => {

            // mint 10,000 USDC to alice
            const mintAmt = 10000n * (10n ** 6n);
            const depositAmt = mintAmt / 5n;
            await token.methods.mint_to_private(admin.getAddress(), alice.getAddress(), mintAmt).send().wait();
            await token.methods.mint_to_public(alice.getAddress(), mintAmt).send().wait();
            const initialBalPriv = await token.methods.balance_of_private(alice.getAddress()).simulate();
            const initialBalPub = await token.methods.balance_of_public(alice.getAddress()).simulate();

            // create input params
            const sortcodeField = Fr.fromBufferReduce(
                Buffer.from('04290953215338').reverse()
            );
            const currencyCodeField = Fr.fromBufferReduce(
                Buffer.from('GBP').reverse()
            );

            // create auth witness so escrow can trasfer from private balance to public
            const action = await token.methods
                .transfer_to_public(
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
            console.log('Alice bal priv: ', aliceBalPriv);
            console.log('Escrow bal public: ', escrowBalPub);
        });
    });

});