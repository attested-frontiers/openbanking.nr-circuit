import {
    AztecAddress,
    createPXEClient,
    Fq,
    Fr,
    SponsoredFeePaymentMethod,
    waitForPXE,
} from '@aztec/aztec.js';
import { getSchnorrAccount } from '@aztec/accounts/schnorr';
import { getDeployedSponsoredFPCAddress, deployEscrowContract, deployTokenContract, getSponsoredFPCInstance } from './helpers.js'
import { SponsoredFPCContract } from "@aztec/noir-contracts.js/SponsoredFPC";

/**
 * Deploys a new token contract and escrow contract to the specified PXE URL. Also grabs
 * FPC address
 */
const deploy = async () => {
    // const pxe = createPXEClient('https://pxe.obsidion.xyz');
    const pxe = createPXEClient('http://localhost:8080');
    await waitForPXE(pxe);

    const secretKey = Fr.random();
    const signingKey = Fq.random();

    // const fpc = await getDeployedSponsoredFPCAddress(pxe);
    const fpc = AztecAddress.fromString('0x0b27e30667202907fc700d50e9bc816be42f8141fae8b9f2281873dbdb9fc2e5');

    const sponsoredFPC = await getSponsoredFPCInstance();
    await pxe.registerContract({
        instance: sponsoredFPC,
        artifact: SponsoredFPCContract.artifact,
    });

    const paymentMethod = new SponsoredFeePaymentMethod(sponsoredFPC.address);

    // @ts-ignore
    const admin = await getSchnorrAccount(pxe, secretKey, signingKey, 0);
    const adminWallet = await admin.waitSetup({ fee: { paymentMethod }, timeout: 180 });

    // const token = await deployTokenContract(adminWallet, paymentMethod);
    // const escrow = await deployEscrowContract(adminWallet, paymentMethod, token);

    // console.log(`VITE_APP_ESCROW_CONTRACT_ADDRESS = "${escrow.address.toString()}"`);
    // console.log(`VITE_APP_TOKEN_CONTRACT_ADDRESS = "${token.address.toString()}"`);
    // console.log(`VITE_APP_TOKEN_ADMIN_SECRET_KEY = "${secretKey.toString()}"`);
    // console.log(`VITE_APP_TOKEN_ADMIN_SIGNING_KEY = "${signingKey.toString()}"`);
    // console.log(`VITE_APP_FPC_ADDRESS = "${fpc.toString()}"`)
};

deploy();
