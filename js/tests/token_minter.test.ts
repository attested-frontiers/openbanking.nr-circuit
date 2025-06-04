import { AccountWalletWithSecretKey, createPXEClient, PXE, SponsoredFeePaymentMethod } from "@aztec/aztec.js";
import { TokenContract, TokenMinterContract } from "../src/artifacts";
import { getDeployedTestAccountsWallets } from "@aztec/accounts/testing";
import { deployTokenContract, deployTokenMinterContract } from '../src/deploy/helpers';
import { getSponsoredFPCInstance } from "../src/utils.js";
import { describe } from "node:test";

const PXE_URL = "http://localhost:8080"

describe("Test token minter contract", () => {
    let admin: AccountWalletWithSecretKey;
    let alice: AccountWalletWithSecretKey;
    let fpc: SponsoredFeePaymentMethod;
    let pxe: PXE;
    let token: TokenContract;
    let tokenMinter: TokenMinterContract;

    beforeAll(async () => {
        pxe = createPXEClient(PXE_URL);
        [admin, alice] = await getDeployedTestAccountsWallets(pxe);
        const sponsoredFPC = await getSponsoredFPCInstance();
        fpc = new SponsoredFeePaymentMethod(sponsoredFPC.address);
        tokenMinter = await deployTokenMinterContract(admin, fpc);
        token = await deployTokenContract(admin, tokenMinter.address, fpc);

        // set token contract in token minter
        await tokenMinter.methods.set_token(token.address).send().wait();
    })

    describe("Test minting", () => {
        it("Test mint public", async () => {
            const mintAmt = 10000n * (10n ** 6n);
            const initialBalance = await token.methods.balance_of_public(alice.getAddress()).simulate();
            // mint tokens
            await tokenMinter.methods.mint_public(alice.getAddress(), mintAmt).send().wait();
            const balanceAfter = await token.methods.balance_of_public(alice.getAddress()).simulate();
            expect(initialBalance).toEqual(0n);
            expect(balanceAfter).toEqual(mintAmt);
        });

        it("Test mint private", async () => {
            const mintAmt = 10000n * (10n ** 6n);
            const initialBalance = await token.methods.balance_of_private(alice.getAddress()).simulate();
            // mint tokens
            await tokenMinter.methods.mint_private(alice.getAddress(), mintAmt).send().wait();
            const balanceAfter = await token.methods.balance_of_private(alice.getAddress()).simulate();
            expect(initialBalance).toEqual(0n);
            expect(balanceAfter).toEqual(mintAmt);
        });
    });
});