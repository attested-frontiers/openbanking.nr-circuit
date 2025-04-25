import {
    createPXEClient,
    Fr,
    waitForPXE,
    NoirCompiledContract,
    AztecAddress
} from '@aztec/aztec.js';
import { getSingleKeyAccount } from '@aztec/accounts/single_key';
import { TokenContract } from '@aztec/noir-contracts.js/Token';
import * as TokenContractArtifactJson from "@aztec/noir-contracts.js/artifacts/token_contract-Token";
import { OpenbankingEscrowContract } from './artifacts/contracts/OpenbankingEscrow.js';
import OpenbankingEscrowArtifactJson from './artifacts/contracts/openbanking_escrow.json' assert { type: 'json' };
import { registerContractClassArtifact } from './verifyContract.js';
import {
    generateVerifyArtifactUrl,
    generateVerifyArtifactPayload,
    generateVerifyInstanceUrl,
    generateVerifyInstancePayload,
    callExplorerApi,
    initialize as initializeExplorerApi,
} from "aztec-scan-sdk";


const USDC_TOKEN = {
    symbol: "USDC",
    name: "Aztec USDC",
    decimals: 6
}

/**
 * CLI Arguments type
 */
interface CLIArgs {
    sandbox: boolean;
    token: string;
}

interface ExplorerArtifacts {
    classId: Fr;
    instanceAddress: AztecAddress;
    artifactObject: NoirCompiledContract;
}

/**
 * Parses command-line arguments for sandbox flag and token string
 * @returns {CLIArgs} Object containing parsed CLI arguments
 */
function parseArgs(): CLIArgs {
    const args = process.argv.slice(2);
    const cliArgs: CLIArgs = {
        sandbox: true, // Default to true if no arguments supplied
        token: ''      // Default to empty string
    };

    if (args.length === 0) {
        return cliArgs;
    }

    for (let i = 0; i < args.length; i++) {
        if (args[i] === '--sandbox') {
            if (i + 1 < args.length && (args[i + 1] === 'true' || args[i + 1] === 'false')) {
                cliArgs.sandbox = args[i + 1] === 'true';
                i++; // Skip the next argument as we've already processed it
            } else {
                displayHelpAndExit('Missing or invalid value for --sandbox flag. Expected "true" or "false".');
            }
        } else if (args[i] === '--token') {
            if (i + 1 < args.length && args[i + 1]) {
                cliArgs.token = args[i + 1];
                i++; // Skip the next argument as we've already processed it
            } else {
                displayHelpAndExit('Missing value for --token flag. Expected a string value.');
            }
        } else {
            displayHelpAndExit(`Unrecognized argument: ${args[i]}`);
        }
    }

    return cliArgs;
}

/**
 * Displays help information and exits with error
 * @param {string} errorMsg - Error message to display
 */
function displayHelpAndExit(errorMsg: string) {
    console.error('Error: ' + errorMsg);
    console.log('\nAvailable commands:');
    console.log('  node --loader ts-node/esm src/deploy.ts                                # Run with sandbox mode (default)');
    console.log('  node --loader ts-node/esm src/deploy.ts --sandbox true                 # Run with sandbox mode enabled');
    console.log('  node --loader ts-node/esm src/deploy.ts --sandbox false                # Run with sandbox mode disabled');
    console.log('  node --loader ts-node/esm src/deploy.ts --token <token-value>          # Specify a token value');
    console.log('  node --loader ts-node/esm src/deploy.ts --sandbox false --token abc123 # Combined usage');
    process.exit(1);
}

const deploy = async () => {
    const cliArgs = parseArgs();
    console.log(`Deploying in ${cliArgs.sandbox ? 'sandbox' : 'production'} mode...`);
    if (cliArgs.token) {
        console.log(`Using token: ${cliArgs.token}`);
    }

    const pxe = createPXEClient('http://localhost:8080');
    await waitForPXE(pxe);

    // @ts-ignore
    const admin = await getSingleKeyAccount(pxe, Fr.random(), 0);
    const adminWallet = await admin.waitSetup();

    let token;
    let tokenAddress;
    if (!cliArgs.token) {
        token = await TokenContract.deploy(
            adminWallet,
            adminWallet.getAddress(),
            USDC_TOKEN.symbol,
            USDC_TOKEN.name,
            USDC_TOKEN.decimals
        )
            .send()
            .deployed();
        tokenAddress = token.address;
    } else {
        tokenAddress = AztecAddress.fromString(cliArgs.token);
    }

    // todo: add pubkey monitoring
    const escrow = await OpenbankingEscrowContract.deploy(adminWallet, tokenAddress, [
        Fr.fromHexString("0x122fe470d24a14ba2e21e27225df5897b36e91e4ac6f62e022d4b901331b9ade"),
        Fr.fromHexString("0x28a4057201b24bfdf7a37dd598077aee7cc969c1f58a3cf6efa28778ba1e35f6"),
        Fr.fromHexString("0x0e2c0956cae7472177eb75f5b7228057b0bca4a15d2f97b3416e4b6dbda116c6"),
        Fr.fromHexString("0x063b9064814feb22c88e0261a7028adeaec3acd41cb92336c3be712dd1bf0a92"),
        Fr.fromHexString("0x1995a9a76e9e03a897b202b27e9a71a7513b733e1a19bbb40cc3f81e2fb2b23f")
    ]).send().deployed();


    console.log('Token contract: ', tokenAddress.toString());
    console.log('Escrow contract: ', escrow.address.toString());
    console.log('Token admin: ', adminWallet.getSecretKey().toString());

    if (!cliArgs.sandbox) {
        console.log('Verifying contract on AztecScan...');
        const artifacts: ExplorerArtifacts[] = [];
        if (token) {
            artifacts.push({
                classId: token.instance.contractClassId,
                instanceAddress: tokenAddress,
                artifactObject: TokenContractArtifactJson
            })
        }
        artifacts.push({
            classId: escrow.instance.contractClassId,
            instanceAddress: escrow.address,
            artifactObject: OpenbankingEscrowArtifactJson
        });
    }
};

const verifySource = async (
    artifacts: ExplorerArtifacts[]
) => {
    // initialize explorer api
    const apiUrl = "https://api.testnet.aztecscan.xyz/v1/";
    const apiKey = "temporary-api-key";
    initializeExplorerApi({ apiUrl, apiKey });

    for (const artifact of artifacts) {
        const { classId, instanceAddress, artifactObject } = artifact;
        // verify contract artifact
        const version = 1; // just gonna use 1 for all versions for now
        const artifactUrl = generateVerifyArtifactUrl(undefined, classId, version);
        const artifactPayload = generateVerifyArtifactPayload(artifactObject);
        await callExplorerApi({
            urlStr: artifactUrl,
            method: "POST",
            postData: JSON.stringify(artifactPayload),
            loggingString: "Register Artifact",
        });

        // verify deployed instance
    }
}

deploy();
