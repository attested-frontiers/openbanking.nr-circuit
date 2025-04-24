import {
    createPXEClient,
    Fq,
    Fr,
    SponsoredFeePaymentMethod,
    waitForPXE,
} from '@aztec/aztec.js';
import { getSchnorrAccount } from '@aztec/accounts/schnorr';
import { getDeployedSponsoredFPCAddress, deployEscrowContract, deployTokenContract } from './helpers'

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

    const fpc = await getDeployedSponsoredFPCAddress(pxe);
    const paymentMethod = new SponsoredFeePaymentMethod(fpc);

    // @ts-ignore
    const admin = await getSchnorrAccount(pxe, secretKey, signingKey, 0);
    const adminWallet = await admin.waitSetup({ fee: { paymentMethod } });

    const token = await deployTokenContract(adminWallet, paymentMethod);
    const escrow = await deployEscrowContract(adminWallet, paymentMethod, token);

    console.log(`VITE_APP_ESCROW_CONTRACT_ADDRESS = "${escrow.address.toString()}"`);
    console.log(`VITE_APP_TOKEN_CONTRACT_ADDRESS = "${token.address.toString()}"`);
    console.log(`VITE_APP_TOKEN_ADMIN_SECRET_KEY = "${secretKey.toString()}"`);
    console.log(`VITE_APP_TOKEN_ADMIN_SIGNING_KEY = "${signingKey.toString()}"`);
    console.log(`VITE_APP_FPC_ADDRESS = "${fpc.toString()}"`)
};

deploy();
