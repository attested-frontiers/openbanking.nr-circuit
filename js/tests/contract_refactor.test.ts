import { AccountWalletWithSecretKey, AztecAddress, BatchCall, ContractInstanceWithAddress, createAztecNodeClient, createPXEClient, Fq, Fr, getContractInstanceFromDeployParams, PublicKeys, PXE, SponsoredFeePaymentMethod, waitForPXE } from '@aztec/aztec.js';
import { OpenbankingEscrowContract, TokenContract } from "../src/artifacts/index.js";
import { getSchnorrAccount, getSchnorrWalletWithSecretKey } from '@aztec/accounts/schnorr';
import { deriveSigningKey } from "@aztec/stdlib/keys";
import { getSponsoredFPCInstance } from '../src/utils.js';
import { SponsoredFPCContract } from "@aztec/noir-contracts.js/SponsoredFPC";

const AZTEC_NODE_URL = "https://aztec-alpha-testnet-fullnode.zkv.xyz";
const PXE_URL = "http://localhost:8080";
const TX_TIMOUT = 600;

const SECRET_KEYS = [
    Fr.fromHexString('0x1d5b8fb967ce66cc3bccce15dfb2963e3f2c86437c2b752aefba9671db75976a'),
    Fr.fromHexString('0x264f49bf2e73738f617effc3fb6efc699a8a3f4faae34a793f81dfad3d8a3d89')
];

const ESCROW_CONTRACT_ADDRESS = AztecAddress.fromString('0x1a3c6abc2760f0de6cb26ba85a98332ea28987df6af8157189d5d890a28a736f');
const TOKEN_CONTRACT_ADDRESS = AztecAddress.fromString('0x14ce3b388d950918e98c7e9d010d5e8ba692884eaf378401f1456cdf82ee7cfa');

const registerContracts = async (pxe: PXE) => {
    const node = createAztecNodeClient(AZTEC_NODE_URL);
    // get payment method
    const sponsored = await getSponsoredFPCInstance();
    const paymentMethod = new SponsoredFeePaymentMethod(sponsored.address);
    const contracts = [
        { instance: sponsored, artifact: SponsoredFPCContract.artifact },
        { instance: await node.getContract(TOKEN_CONTRACT_ADDRESS), artifact: TokenContract.artifact },
        { instance: await node.getContract(ESCROW_CONTRACT_ADDRESS), artifact: OpenbankingEscrowContract.artifact }
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
    let escrow: OpenbankingEscrowContract;
    let paymentMethod: SponsoredFeePaymentMethod;
    let pxe: PXE;
    let token: TokenContract;

    beforeAll(async () => {
        const pxe = createPXEClient(PXE_URL);
        await waitForPXE(pxe);
        ({ paymentMethod } = await registerContracts(pxe));

        const account1 = await getSchnorrAccount(pxe, SECRET_KEYS[0], deriveSigningKey(SECRET_KEYS[0]), 0);
        const account2 = await getSchnorrAccount(pxe, SECRET_KEYS[1], deriveSigningKey(SECRET_KEYS[1]), 0);

        // await account1.waitSetup({ fee: { paymentMethod }, timeout: TX_TIMOUT });
        // await account2.waitSetup({ fee: { paymentMethod }, timeout: TX_TIMOUT });

        alice = await account1.getWallet();
        bob = await account2.getWallet();

        escrow = await OpenbankingEscrowContract.at(ESCROW_CONTRACT_ADDRESS, alice);
        token = await TokenContract.at(TOKEN_CONTRACT_ADDRESS, alice);

        // mint token balance to alice and bob
        // const mintAmount = 10000 * (10 ** 6);
        // await token.methods.mint_to_public(alice.getAddress(), mintAmount).send({ fee: { paymentMethod } }).wait();
        // await token.methods.mint_to_private(alice.getAddress(), alice.getAddress(), mintAmount).send({ fee: { paymentMethod } }).wait();
    });

    describe('Fetch balances', () => {
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
    })
});