import { AccountWalletWithSecretKey, AztecAddress, AztecNode, BatchCall, ContractInstanceWithAddress, createAztecNodeClient, createPXEClient, Fq, Fr, getContractInstanceFromDeployParams, PublicKeys, PXE, SponsoredFeePaymentMethod, waitForPXE } from '@aztec/aztec.js';
import { OpenbankingEscrowContract, TokenContract } from "../src/artifacts/index.js";
import { getSchnorrAccount, getSchnorrWalletWithSecretKey } from '@aztec/accounts/schnorr';
import { deriveSigningKey } from "@aztec/stdlib/keys";
import { deployEscrowContract, deployTokenContract } from '../src/deploy/helpers.js';
import { getSponsoredFPCInstance } from '../src/utils.js';
import { SponsoredFPCContract } from "@aztec/noir-contracts.js/SponsoredFPC";

const AZTEC_NODE_URL = "https://aztec-alpha-testnet-fullnode.zkv.xyz";
const PXE_URL = "http://localhost:8080";
const TX_TIMOUT = 600;

const deployWallets = async (pxe: PXE, paymentMethod: SponsoredFeePaymentMethod, amount: number) => {
    const wallets: Array<AccountWalletWithSecretKey> = [];
    const secretKeys = new Array(amount).fill(Fr.random());
    for (const key of secretKeys) {
        const account = await getSchnorrAccount(pxe, key, deriveSigningKey(key), 0);
        await account.deploy({ fee: { paymentMethod } }).wait({ timeout: TX_TIMOUT })
        wallets.push(await account.getWallet());
    }
    return wallets;
}

const registerContracts = async (pxe: PXE) => {
    const node = createAztecNodeClient(AZTEC_NODE_URL);
    // get payment method
    const sponsored = await getSponsoredFPCInstance();
    const paymentMethod = new SponsoredFeePaymentMethod(sponsored.address);
    const contracts = [
        { instance: sponsored, artifact: SponsoredFPCContract.artifact },
        // { instance: await node.getContract(TOKEN_CONTRACT_ADDRESS), artifact: TokenContract.artifact },
        // { instance: await node.getContract(ESCROW_CONTRACT_ADDRESS), artifact: OpenbankingEscrowContract.artifact }
    ];

    for (const { instance, artifact } of contracts) {
        if (instance) {
            await pxe.registerContract({ instance, artifact });
        }
    }

    return { paymentMethod }
}

describe("Test contract / account registration using PXE client", () => {
    let admin: AccountWalletWithSecretKey;
    let alice: AccountWalletWithSecretKey;
    let bob: AccountWalletWithSecretKey;
    let corey: AccountWalletWithSecretKey;
    let david: AccountWalletWithSecretKey;
    let escrow: OpenbankingEscrowContract;
    let node: AztecNode;
    let paymentMethod: SponsoredFeePaymentMethod;
    let pxe: PXE;
    let token: TokenContract;

    beforeAll(async () => {
        node = createAztecNodeClient(AZTEC_NODE_URL);
        pxe = createPXEClient(PXE_URL);
        await waitForPXE(pxe);
        ({ paymentMethod } = await registerContracts(pxe));




        [admin, alice, bob, corey, david] = await deployWallets(pxe, paymentMethod, 5);

        token = await deployTokenContract(admin, paymentMethod);
        escrow = await deployEscrowContract(admin, paymentMethod, token.address);

        // mint token balance to alice and bob
        // const mintAmount = 10000 * (10 ** 6);
        // await token.methods.mint_to_public(alice.getAddress(), mintAmount).send({ fee: { paymentMethod } }).wait();
        // await token.methods.mint_to_private(alice.getAddress(), alice.getAddress(), mintAmount).send({ fee: { paymentMethod } }).wait();
    });

    xdescribe('Fetch balances', () => {
        it('Fetch sequentially with seperate RPC calls', async () => {
            console.time('token-sequential-fetch');
            await token.methods.balance_of_public(alice.getAddress()).simulate();
            await token.methods.balance_of_private(alice.getAddress()).simulate();
            console.timeEnd('token-sequential-fetch');
        });

        it("Fetch in parallel with seperate RPC calls", async () => {
            console.time('token-parallel-fetch');
            const calls = [token.methods.balance_of_public(alice.getAddress()), token.methods.balance_of_private(alice.getAddress())];
            await Promise.all(calls.map(async (call) => await call.simulate()))
            console.timeEnd('token-parallel-fetch');
        });

        it("Create batched Aztec request", async () => {
            console.time('token-batch-request')
            const calls = [token.methods.balance_of_public(alice.getAddress()), token.methods.balance_of_private(alice.getAddress())];
            const batch = new BatchCall(alice, calls);
            await batch.simulate({ fee: { paymentMethod } });
            console.timeEnd('token-batch-request')
        });
    });

    describe("Fetch escrow positions", () => {
        it('Fetch sequentially with seperate RPC calls', async () => {
            console.time('escrow-sequential-fetch');
            // await token.methods.balance_of_public(alice.getAddress()).simulate();
            // await token.methods.balance_of_private(alice.getAddress()).simulate();
            console.timeEnd('escrow-sequential-fetch');
        });

    });
});