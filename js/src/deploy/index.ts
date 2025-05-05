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
import { TokenContract } from "../artifacts/index.js";

// Set as minters 
const NETWORK_ARGS = ["testnet", "sandbox"];
const NETWORK_ARG_NAME = "network";


const parseAztecNetworkArg = (args: string[]): string => {
    const networkArg = args.find((arg) => arg.startsWith(`--${NETWORK_ARG_NAME}=`))
    if (!networkArg) {
        console.log(console.error(`❌ Missing required argument: --${NETWORK_ARG_NAME}=<value>`));
        process.exit(1);
    }
    const value = networkArg.split(networkArg)[1];
    if (NETWORK_ARGS.includes(value)) {
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

    const secretKey = Fr.random();
    const signingKey = Fq.random();
    const pxe = createPXEClient('http://localhost:8080');
    await waitForPXE(pxe);

    // register FPC contract
    const sponsoredFPC = await getSponsoredFPCInstance();
    await pxe.registerContract({
        instance: sponsoredFPC,
        artifact: SponsoredFPCContract.artifact,
    });

    const paymentMethod = new SponsoredFeePaymentMethod(sponsoredFPC.address);

    // @ts-ignore
    const admin = await getSchnorrAccount(pxe, secretKey, signingKey, 0);
    const adminWallet = await admin.waitSetup({ fee: { paymentMethod }, timeout: AZTEC_TIMEOUT });

    const aztecNetworkArg = parseAztecNetworkArg(process.argv);

    let token: AztecAddress;
    if (aztecNetworkArg === "testnet") {
        token = AztecAddress.fromString("0x04e1b62d4c68730f345c41d92852ead8237f0ba198a7e6973ab03806aa43ce75");
    } else {
        const tokenContract = await deployTokenContract(adminWallet, paymentMethod)
        token = tokenContract.address;
    }
    const escrow = await deployEscrowContract(adminWallet, paymentMethod, token);

    console.log(`VITE_APP_ESCROW_CONTRACT_ADDRESS = "${escrow.address.toString()}"`);
    console.log(`VITE_APP_TOKEN_CONTRACT_ADDRESS = "${token.toString()}"`);
    process.exit(0);
};

deploy();
