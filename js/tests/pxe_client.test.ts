import { AccountWalletWithSecretKey, AztecAddress, ContractInstanceWithAddress, createAztecNodeClient, createPXEClient, Fq, Fr, getContractInstanceFromDeployParams, PublicKeys, PXE, SponsoredFeePaymentMethod, waitForPXE } from '@aztec/aztec.js'
import { TokenContract } from "@aztec/noir-contracts.js/Token";
import { OpenbankingEscrowContract } from "../src/artifacts";
import { getDeployedTestAccountsWallets } from "@aztec/accounts/testing";
import { getSchnorrAccount } from '@aztec/accounts/schnorr';
import { USDC_TOKEN } from "../src/constants";
import { SponsoredFPCContract } from '@aztec/noir-contracts.js/SponsoredFPC';
import { getSponsoredFPCInstance } from '../src/deploy/helpers.js'

const AZTEC_NODE_URL = "http://34.107.66.170";
const PXE_URL = "http://localhost:8080";

// VITE_APP_ESCROW_CONTRACT_ADDRESS = "0x218226393a4d15eaaec496f0de28dce124f263eded27bb466668be5b4838aea9"
// VITE_APP_TOKEN_CONTRACT_ADDRESS = "0x055f179cb5d776834fe6588bd3e2f0a4337057a90fa03af8f4aadfcd55674585"
const TOKEN_ADMIN_SECRET_KEY = "0x04200388e9a46f25b9014ac9aa775d111976956fe20be5347803dda1e5f07cb1"
const TOKEN_ADMIN_SIGNING_KEY = "0x2cad3c699a74f33e26de38f1a5f621be5d7e888e28db86b953c2c902276b859c"
// VITE_APP_FPC_ADDRESS = "0x0b27e30667202907fc700d50e9bc816be42f8141fae8b9f2281873dbdb9fc2e5"

describe("Test contract / account registration using PXE client", () => {
    let admin: AccountWalletWithSecretKey;
    // let alice: AccountWalletWithSecretKey;
    // let bob: AccountWalletWithSecretKey;
    // let escrow: OpenbankingEscrowContract;
    let pxe: PXE;
    // let token: TokenContract;

    beforeAll(async () => {
        pxe = createPXEClient(PXE_URL);
        await waitForPXE(pxe);
        const node = createAztecNodeClient(AZTEC_NODE_URL);

        const escrowAddress = AztecAddress.fromString("0x218226393a4d15eaaec496f0de28dce124f263eded27bb466668be5b4838aea9");
        const tokenAddress = AztecAddress.fromString('0x055f179cb5d776834fe6588bd3e2f0a4337057a90fa03af8f4aadfcd55674585');

        const tokenInstance = await node.getContract(tokenAddress);
        const escrowInstance = await node.getContract(escrowAddress);
        const sponsoredFPC = await getSponsoredFPCInstance();


        // register contracts
        await pxe.registerContract({ instance: tokenInstance as ContractInstanceWithAddress, artifact: TokenContract.artifact })
        await pxe.registerContract({ instance: escrowInstance as ContractInstanceWithAddress, artifact: OpenbankingEscrowContract.artifact })
        await pxe.registerContract({
            instance: sponsoredFPC,
            artifact: SponsoredFPCContract.artifact,
        });

        const adminAcc = await getSchnorrAccount(pxe, Fr.fromHexString(TOKEN_ADMIN_SECRET_KEY), Fq.fromHexString(TOKEN_ADMIN_SIGNING_KEY), 0);
        admin = await adminAcc.getWallet();

        // register token admin
        await pxe.registerAccount(Fr.fromHexString(TOKEN_ADMIN_SECRET_KEY), admin.getCompleteAddress().partialAddress);

        // get registered contracts
        const contracts = await pxe.getContracts();
        console.log('Contracts: ', contracts);

        // get registered accounts
        const registeredAccounts = await pxe.getRegisteredAccounts();
        console.log('Registered accounts: ', registeredAccounts);

        // const adminAcc = await getSchnorrAccount(pxe, Fr.fromHexString(TOKEN_ADMIN_SECRET_KEY), Fq.fromHexString(TOKEN_ADMIN_SIGNING_KEY), 0);
        // admin = await adminAcc.getWallet();
        // console.log('Admin: ', admin.getAddress().toString())
        // check that token admin is registered
        // const registered = await pxe.getRegisteredAccounts();
        // console.log('Registered: ', registered);
    })

    describe("Contracts should register in PXE and fetch correct state", () => {
        it("Check that contracts registered on sandbox PXE", () => {

            // mint tokens to public and private

            // console.log('Token: ', token);
            // console.log('Escrow: ', escrow);
        });
    });
});