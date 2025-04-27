import {
    AztecAddress,
    ContractArtifact,
    ContractBase,
    createPXEClient,
    Fq,
    Fr,
    NoirCompiledContract,
    SponsoredFeePaymentMethod,
    waitForPXE,
} from '@aztec/aztec.js';
import { getSchnorrAccount } from '@aztec/accounts/schnorr';
import { parseArgs } from './cli.js';
import { deployEscrowContract, deployTokenContract, getSponsoredFPCInstance } from './helpers.js'
import { verifySource } from './verify.js';
import * as TokenContractArtifactJson from '../../node_modules/@aztec/noir-contracts.js/artifacts/token_contract-Token.json' with { type: 'json' };;
import { OpenbankingEscrowContractArtifact } from '../artifacts/contracts/OpenbankingEscrow.js';
const pxeURL = "http://localhost:8080";
const timeout = 180;
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

    // initialize fpc
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
        // if (token) {
        //     contractsToVerify.push(token)
        //     artifactsToVerify.push(TokenContractArtifactJson);
        // }
        contractsToVerify.push(escrow);
        artifactsToVerify.push(OpenbankingEscrowContractArtifact);
        verifySource(contractsToVerify, artifactsToVerify)
    }
};

deploy();
