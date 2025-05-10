import {
    AztecAddress,
    ContractArtifact,
    ContractBase,
    createPXEClient,
    Fq,
    Fr,
    SponsoredFeePaymentMethod,
    waitForPXE,
} from '@aztec/aztec.js';
import { readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from 'url';
import { getSchnorrAccount } from '@aztec/accounts/schnorr';
import { parseArgs } from './cli.js';
import { deployEscrowContract, deployTokenContract, getSponsoredFPCInstance } from './helpers.js'
import { verifySource } from './verify.js';
// import { ContractDeployerMetadata, VerifyInstanceArgs } from 'aztec-scan-sdk';

import {
    generateVerifyArtifactUrl,
    generateVerifyArtifactPayload,
    generateVerifyInstanceUrl,
    generateVerifyInstancePayload,
    callExplorerApi,
    initialize as initializeExplorerApi,
    ContractDeployerMetadata,
    VerifyInstanceArgs
} from "aztec-scan-sdk";
import { OpenbankingEscrowContractArtifact } from '../artifacts/contracts/OpenbankingEscrow.js';
const pxeURL = "http://localhost:8080";
const timeout = 180;

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const TokenContractArtifactJson = JSON.parse(
    readFileSync(
        join(
            __dirname,
            "../../node_modules/@aztec/noir-contracts.js/artifacts/token_contract-Token.json",
        ),
        "utf-8"
    )
);

const EscrowContractArtifact = JSON.parse(
    readFileSync(
        join(
            __dirname,
            "../artifacts/contracts/openbanking_escrow.json",
        ),
        "utf-8"
    )
);

const TOKEN_METADATA: ContractDeployerMetadata = {
    contractIdentifier: "USDC_Token",
    details: "USDC Test Token",
    creatorName: "Aztec Labs",
    creatorContact: "",
    appUrl: "https://aztec.network",
    repoUrl: "https://github.com/AztecProtocol/aztec-packages/tree/master/noir-projects/noir-contracts/contracts/app/token_contract",
    reviewedAt: new Date().toISOString(),
    contractType: "Token",
};

const BOLT_METADATA: ContractDeployerMetadata = {
    contractIdentifier: "BOLT_Escrow",
    details: "B.O.L.T. Escrow Contract",
    creatorName: "Attested Frontiers",
    creatorContact: "",
    appUrl: "https://app.bolts.money",
    repoUrl: "https://github.com/attsted-frontiers/openbanking.nr-circuit",
    reviewedAt: new Date().toISOString(),
    contractType: "Unknown",
};

/**
 * Deploys a new token contract and escrow contract to the specified PXE URL. Also grabs
 * FPC address
 */
const deploy = async () => {
    // handle cli args
    const cliArgs = parseArgs();
    console.log(`Deploying to ${cliArgs.sandbox ? 'sandbox' : 'production'} chain...`);
    if (cliArgs.token) {
        console.log(`Using existing token: ${cliArgs.token}`);
    }

    // create PXE
    const pxe = createPXEClient(pxeURL);
    await waitForPXE(pxe);

    // // initialize fpc
    const sponsoredFPC = await getSponsoredFPCInstance(pxe);
    const paymentMethod = new SponsoredFeePaymentMethod(sponsoredFPC.address);

    // deploy admin wallet
    const secretKey = Fr.random();
    const signingKey = Fq.random();
    const admin = await getSchnorrAccount(pxe, secretKey, signingKey, 0);
    const adminWallet = await admin.waitSetup({ fee: { paymentMethod }, timeout });

    // if no token is provided, deploy a new token contract
    let token;
    let tokenAddress;
    if (!cliArgs.token) {
        token = await deployTokenContract(adminWallet, paymentMethod);
        tokenAddress = token.address;
    } else {
        tokenAddress = AztecAddress.fromString(cliArgs.token);
    }

    // register token contract
    // const tokenAddress 
    const escrow = await deployEscrowContract(adminWallet, paymentMethod, tokenAddress);

    console.log(`======[Deployment Summary]======`);
    console.log(`Deployed to PXE: ${pxeURL} (${cliArgs.sandbox ? 'sandbox' : 'production'})`);
    console.log(`FPC Address: ${sponsoredFPC.address}`);
    console.log(`Deployed by Admin Address: ${adminWallet.getAddress()}`);
    if (cliArgs.token) {
        console.log(`Used existing payment token contract at: ${tokenAddress}`);
    } else {
        console.log(`Deployed Token Contract to: ${tokenAddress}`);
    }
    console.log(`Deployed Escrow Contract to: ${escrow.address}`);
    // console.log(`======[VITE ENV]======`);
    // console.log(`VITE_APP_ESCROW_CONTRACT_ADDRESS = "${escrow.address.toString()}"`);
    // console.log(`VITE_APP_TOKEN_CONTRACT_ADDRESS = "${tokenAddress.toString()}"`);
    // console.log(`VITE_APP_TOKEN_ADMIN_SECRET_KEY = "${secretKey.toString()}"`);
    // console.log(`VITE_APP_TOKEN_ADMIN_SIGNING_KEY = "${signingKey.toString()}"`);
    // console.log(`VITE_APP_FPC_ADDRESS = "${sponsoredFPC.address}"`)
    // console.log(`VITE_APP_PXE_URL = "${pxeURL}"`);
    // console.log(`======[END OF DEPLOYMENT]======`);
    if (!cliArgs.sandbox) {
        console.log(`\n\n\n Verifying contracts on Aztec Explorer...`);

        const contractsToVerify: ContractBase[] = [];
        const artifactsToVerify: ContractArtifact[] = [];
        const metadata: ContractDeployerMetadata[] = [];
        if (!cliArgs.token) {
            // contractsToVerify.push(token)
            // artifactsToVerify.push(TokenContractArtifactJson);
            // metadata.push(TOKEN_METADATA);
        }

        // const apiUrl = rx1b5ab25fbc5f23ca1f0f94c95b6ba16e83c19e58da5c88c4c030d827e008d202";
        contractsToVerify.push(escrow);
        artifactsToVerify.push(EscrowContractArtifact);
        metadata.push(BOLT_METADATA);

        const args = [
            "0x0cdcbb9f9ab1bb754f924d9b0322d1f0c6ba94bda97b3ec59c605c77a62cab13",
        ]
        // console.log("args: ", args);
        console.log("Pubkey String: ", adminWallet.getCompleteAddress().publicKeys.toString());
        console.log("Deployer Address: ", adminWallet.getAddress().toString());
        // const verifyArgs: VerifyInstanceArgs = {
        //     publicKeysString: pubkeyString,
        //     deployer: deployerAddress,
        //     salt: salt,
        //     constructorArgs: args,
        //     artifactObj: EscrowContractArtifact,
        // };

        const verifyArgs: VerifyInstanceArgs = {
            publicKeysString: escrow.instance.publicKeys.toString(),
            deployer: adminWallet.getAddress().toString(),
            salt: escrow.instance.salt.toString(),
            constructorArgs: args,
            artifactObj: EscrowContractArtifact,
        };

        // const verifyUrl = generateVerifyInstanceUrl(
        //     undefined,
        //     instanceAddress,
        // );
        // const verifyPayload = {
        //     deployerMetadata: BOLT_METADATA,
        //     verifiedDeploymentArguments: generateVerifyInstancePayload(verifyArgs),
        // };
        // await callExplorerApi({
        //     loggingString: `Verify Escrow Instance`,
        //     urlStr: verifyUrl,
        //     postData: JSON.stringify(verifyPayload),
        //     method: "POST",
        //   });
        console.log("isntance : ", escrow.address);
        console.log("pubkey isntance: ", escrow.instance.publicKeys.toString());
        console.log("salt: ", escrow.instance.salt.toString());

        await verifySource(
            escrow.instance.publicKeys,
            adminWallet.getAddress(),
            contractsToVerify,
            artifactsToVerify,
            metadata,
            [verifyArgs],
        );
    }
};

deploy();
