import {
    AccountWalletWithSecretKey,
    ContractInstanceWithAddress,
    createPXEClient,
    Fq,
    Fr,
    getContractInstanceFromDeployParams,
    PXE,
    SponsoredFeePaymentMethod,
    waitForPXE,
} from '@aztec/aztec.js';
import { getSchnorrAccount } from '@aztec/accounts/schnorr';
import { TokenContract } from '@aztec/noir-contracts.js/Token';
import { OpenbankingEscrowContract } from './artifacts/contracts/OpenbankingEscrow.js';
import { SPONSORED_FPC_SALT } from '@aztec/constants';
import { SponsoredFPCContract } from '@aztec/noir-contracts.js/SponsoredFPC';

const USDC_TOKEN = {
    symbol: 'USDC',
    name: 'Aztec USDC',
    decimals: 6,
};

const deployEscrowContract = async (adminWallet: AccountWalletWithSecretKey, paymentMethod: SponsoredFeePaymentMethod, token: TokenContract): Promise<OpenbankingEscrowContract> => {
    return await OpenbankingEscrowContract.deploy(
        adminWallet,
        token.address,
        [
            Fr.fromHexString(
                '0x122fe470d24a14ba2e21e27225df5897b36e91e4ac6f62e022d4b901331b9ade'
            ),
            Fr.fromHexString(
                '0x28a4057201b24bfdf7a37dd598077aee7cc969c1f58a3cf6efa28778ba1e35f6'
            ),
            Fr.fromHexString(
                '0x0e2c0956cae7472177eb75f5b7228057b0bca4a15d2f97b3416e4b6dbda116c6'
            ),
            Fr.fromHexString(
                '0x063b9064814feb22c88e0261a7028adeaec3acd41cb92336c3be712dd1bf0a92'
            ),
            Fr.fromHexString(
                '0x1995a9a76e9e03a897b202b27e9a71a7513b733e1a19bbb40cc3f81e2fb2b23f'
            ),
        ]
    )
        .send({ fee: { paymentMethod } })
        .deployed();
}

const deployTokenContract = async (adminWallet: AccountWalletWithSecretKey, paymentMethod: SponsoredFeePaymentMethod): Promise<TokenContract> => {
    return await TokenContract.deploy(
        adminWallet,
        adminWallet.getAddress(),
        USDC_TOKEN.symbol,
        USDC_TOKEN.name,
        USDC_TOKEN.decimals,
    )
        .send({ fee: { paymentMethod } })
        .deployed();
}

const getSponsoredFPCInstance = async (): Promise<ContractInstanceWithAddress> => {
    return await getContractInstanceFromDeployParams(SponsoredFPCContract.artifact, {
        salt: new Fr(SPONSORED_FPC_SALT),
    });
}

const getSponsoredFPCAddress = async () => {
    return (await getSponsoredFPCInstance()).address;
}

const getDeployedSponsoredFPCAddress = async (pxe: PXE) => {
    const fpc = await getSponsoredFPCAddress();
    const contracts = await pxe.getContracts();
    if (!contracts.find(c => c.equals(fpc))) {
        throw new Error('SponsoredFPC not deployed.');
    }
    return fpc;
}

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
