import {
    AztecAddress,
    createPXEClient,
    Fq,
    Fr,
    SponsoredFeePaymentMethod,
    waitForPXE,
} from '@aztec/aztec.js';
import { getSchnorrAccount } from '@aztec/accounts/schnorr';
import { deployEscrowContract, deployTokenContract, AZTEC_TIMEOUT } from './helpers.js'
import { SponsoredFPCContract } from "@aztec/noir-contracts.js/SponsoredFPC";
import { getSponsoredFPCInstance } from "../utils.js";

const OBSIDION_ACCOUNTS = ["0x1d39ac12135e40920a10a84d19b560c9b5582ea3854720f835e3812a00ee61ac", "0x1fd950a7bc46b881f12ab388716eb80ddb4d8d3469eb6289a71d77eb13889140"];

/**
 * Deploys a new token contract and escrow contract to the specified PXE URL. Also grabs
 * FPC address
 */
const deploy = async () => {
    const pxe = createPXEClient('http://localhost:8080');
    await waitForPXE(pxe);

    const secretKey = Fr.random();
    const signingKey = Fq.random();

    const sponsoredFPC = await getSponsoredFPCInstance();
    await pxe.registerContract({
        instance: sponsoredFPC,
        artifact: SponsoredFPCContract.artifact,
    });

    const paymentMethod = new SponsoredFeePaymentMethod(sponsoredFPC.address);

    // @ts-ignore
    const admin = await getSchnorrAccount(pxe, secretKey, signingKey, 0);
    const adminWallet = await admin.waitSetup({ fee: { paymentMethod }, timeout: AZTEC_TIMEOUT });

    const token = await deployTokenContract(adminWallet, paymentMethod);
    const escrow = await deployEscrowContract(adminWallet, paymentMethod, token);

    // mint tokens to obsidion accounts
    for (const account of OBSIDION_ACCOUNTS) {
        await token.methods.set_minter(AztecAddress.fromString(account), true).send({ fee: { paymentMethod } }).wait();
    }

    console.log(`VITE_APP_ESCROW_CONTRACT_ADDRESS = "${escrow.address.toString()}"`);
    console.log(`VITE_APP_TOKEN_CONTRACT_ADDRESS = "${token.address.toString()}"`);
    console.log(`VITE_APP_TOKEN_ADMIN_SECRET_KEY = "${secretKey.toString()}"`);
    console.log(`VITE_APP_TOKEN_ADMIN_SIGNING_KEY = "${signingKey.toString()}"`);
    console.log(`VITE_APP_FPC_ADDRESS = "${sponsoredFPC.address.toString()}"`);
};

deploy();
