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

    const aztecNetworkArg = parseAztecNetworkArg(process.argv);

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

    let token: AztecAddress;
    if (aztecNetworkArg === "testnet") {
        token = AztecAddress.fromString("0x2ab7cf582347c8a2834e0faf98339372118275997e14c5a77054bb345362e878");
    } else {
        const tokenContract = await deployTokenContract(adminWallet, paymentMethod)
        token = tokenContract.address;
        const mintAmt = 10000n * (10n ** 6n);
        const address = AztecAddress.fromString('0x28b466970bf238bf88131157829bab2975798fa524a20ba0c41282535f774718');
        await tokenContract.methods.mint_to_private(admin.getAddress(), address, mintAmt).send({ fee: { paymentMethod } }).wait();
        await tokenContract.methods.mint_to_public(address, mintAmt).send({ fee: { paymentMethod } }).wait();
    }
    const escrow = await deployEscrowContract(adminWallet, paymentMethod, token);

    console.log(`VITE_APP_ESCROW_CONTRACT_ADDRESS = "${escrow.address.toString()}"`);
    console.log(`VITE_APP_TOKEN_CONTRACT_ADDRESS = "${token.toString()}"`);
    process.exit(0);
};

deploy();
