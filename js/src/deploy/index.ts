import {
    AztecAddress,
    createPXEClient,
    Fq,
    Fr,
    SponsoredFeePaymentMethod,
    waitForPXE,
} from '@aztec/aztec.js';
import { getSchnorrAccount } from '@aztec/accounts/schnorr';
import { deployEscrowContract, deployTokenContract, AZTEC_TIMEOUT, deployTokenMinterContract } from './helpers.js'
import { SponsoredFPCContract } from "@aztec/noir-contracts.js/SponsoredFPC";
import { getSponsoredFPCInstance } from "../utils.js";
import { TokenMinterContract } from "../artifacts/index.js";

// Set as minters 
const NETWORK_ARGS = ["testnet", "sandbox"];
const NETWORK_ARG_NAME = "network";


const parseAztecNetworkArg = (args: string[]): string => {
    const networkArg = args.find((arg) => arg.startsWith(`--${NETWORK_ARG_NAME}=`))
    if (!networkArg) {
        console.log(console.error(`❌ Missing required argument: --${NETWORK_ARG_NAME}=<value>`));
        process.exit(1);
    }
    const value = networkArg.split('=')[1];
    if (!NETWORK_ARGS.includes(value)) {
        console.log(console.error("❌ Network value not testnet or sandbox"));
        process.exit(1);
    }
    return value
}

/**
 * Deploys a new token contract and escrow contract to the specified PXE URL. Also grabs
 * FPC address
 */
const deploy = async () => {
    let token: AztecAddress;
    let tokenMinterContract: TokenMinterContract | undefined = undefined;

    // const secretKey = Fr.random();
    // const signingKey = Fq.random();
    // const pxe = createPXEClient('http://localhost:8080');
    // await waitForPXE(pxe);

    // // register FPC contract
    // const sponsoredFPC = await getSponsoredFPCInstance();
    // await pxe.registerContract({
    //     instance: sponsoredFPC,
    //     artifact: SponsoredFPCContract.artifact,
    // });

    // const paymentMethod = new SponsoredFeePaymentMethod(sponsoredFPC.address);

    // // @ts-ignore
    // const admin = await getSchnorrAccount(pxe, secretKey, signingKey, 0);
    // const adminWallet = await admin.waitSetup({ fee: { paymentMethod }, timeout: AZTEC_TIMEOUT });

    const aztecNetworkArg = parseAztecNetworkArg(process.argv);

    console.log('Aztec network arg: ', aztecNetworkArg);

    // if (aztecNetworkArg === "testnet") {
    //     token = AztecAddress.fromString("0x0cd9912580b900c3685c6fa2f7098eae9eae222eb4f3cf7724eb9bfb1a038297");
    // } else {
    //     tokenMinterContract = await deployTokenMinterContract(adminWallet, paymentMethod);
    //     const tokenContract = await deployTokenContract(adminWallet, tokenMinterContract.address, paymentMethod)
    //     token = tokenContract.address;
    //     await tokenMinterContract.methods.set_token(token).send({ fee: { paymentMethod } }).wait();
    // }
    // const escrow = await deployEscrowContract(adminWallet, paymentMethod, token);
    // // assign token to minter contract

    // console.log(`VITE_APP_ESCROW_CONTRACT_ADDRESS = "${escrow.address.toString()}"`);
    // console.log(`VITE_APP_TOKEN_CONTRACT_ADDRESS = "${token.toString()}"`);
    // if (tokenMinterContract) {
    //     console.log(`VITE_APP_TOKEN_MINTER_CONTRACT_ADDRESS = "${tokenMinterContract.address.toString()}"`)
    // }
    // process.exit(0);
};

deploy();
