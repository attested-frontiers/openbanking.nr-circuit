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

// tx timeout in seconds
export const AZTEC_TIMEOUT = 300;

export const deployEscrowContract = async (adminWallet: AccountWalletWithSecretKey, paymentMethod: SponsoredFeePaymentMethod, token: TokenContract): Promise<OpenbankingEscrowContract> => {
    return await OpenbankingEscrowContract.deploy(
        adminWallet,
        token.address,
    )
        .send({ fee: { paymentMethod } })
        .deployed({ timeout: AZTEC_TIMEOUT });
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
        .deployed({ timeout: AZTEC_TIMEOUT });
}

export const getSponsoredFPCInstance = async (): Promise<ContractInstanceWithAddress> => {
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