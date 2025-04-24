import {
    AccountWalletWithSecretKey, AztecAddress,
    ContractInstanceWithAddress, Fr, getContractInstanceFromDeployParams,
    PXE,
    SponsoredFeePaymentMethod
} from "@aztec/aztec.js";
import { TokenContract } from '@aztec/noir-contracts.js/Token';
import { OpenbankingEscrowContract } from '../artifacts/contracts/OpenbankingEscrow.js';
import { USDC_TOKEN } from "../constants.js";
import { SPONSORED_FPC_SALT } from '@aztec/constants';
import { SponsoredFPCContract } from '@aztec/noir-contracts.js/SponsoredFPC';

export const deployEscrowContract = async (adminWallet: AccountWalletWithSecretKey, paymentMethod: SponsoredFeePaymentMethod, token: TokenContract): Promise<OpenbankingEscrowContract> => {
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

export const deployTokenContract = async (adminWallet: AccountWalletWithSecretKey, paymentMethod: SponsoredFeePaymentMethod): Promise<TokenContract> => {
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

/**
 * Gets deployed Fee Payment Contract from supplied PXE
 * 
 * @param pxe - Aztec private execution environment instance
 * @returns - promise containing AztecAddress of fpc contract
 */
export const getDeployedSponsoredFPCAddress = async (pxe: PXE): Promise<AztecAddress> => {
    const fpc = await getSponsoredFPCAddress();
    const contracts = await pxe.getContracts();
    if (!contracts.find(c => c.equals(fpc))) {
        throw new Error('SponsoredFPC not deployed.');
    }
    return fpc;
}