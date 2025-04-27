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
import { GasFees, GasSettings } from "@aztec/stdlib/gas";

export const adjustGasFee = async <T extends { getCurrentBaseFees: () => Promise<GasFees> }>(
    pxeEntrypoint: T,
    multiple: bigint
): Promise<GasSettings> => {
    const maxFeesPerGas = await pxeEntrypoint.getCurrentBaseFees().then(res => res.mul(multiple))
    return GasSettings.default({ maxFeesPerGas });
}

export const deployEscrowContract = async (
    adminWallet: AccountWalletWithSecretKey,
    paymentMethod: SponsoredFeePaymentMethod,
    tokenAddress: AztecAddress,
    feeMultiple: bigint = 1n,
    timeout: number = 300
): Promise<OpenbankingEscrowContract> => {
    const gasSettings = await adjustGasFee(adminWallet, feeMultiple);
    return await OpenbankingEscrowContract.deploy(
        adminWallet,
        tokenAddress,
        [Fr.ZERO, Fr.ZERO, Fr.ZERO, Fr.ZERO, Fr.ZERO],
    )
        .send({ fee: { paymentMethod, gasSettings } })
        .deployed({ timeout });
}

export const deployTokenContract = async (
    adminWallet: AccountWalletWithSecretKey,
    paymentMethod: SponsoredFeePaymentMethod,
    feeMultiple: bigint = 1n,
    timeout: number = 300
): Promise<TokenContract> => {
    const gasSettings = await adjustGasFee(adminWallet, feeMultiple);
    return await TokenContract.deploy(
        // @ts-ignore
        adminWallet,
        adminWallet.getAddress(),
        USDC_TOKEN.symbol,
        USDC_TOKEN.name,
        USDC_TOKEN.decimals,
    )
        //@ts-ignore
        .send({ fee: { paymentMethod, gasSettings } })
        .deployed({ timeout });
}

/**
 * Gets deployed Fee Payment Contract from supplied PXE
 * 
 * @param pxe - Aztec private execution environment instance
 * @returns - promise containing AztecAddress of fpc contract
 */
export const getSponsoredFPCInstance = async (pxe: PXE): Promise<ContractInstanceWithAddress> => {
    // @ts-ignore
    const sponsoredFPC = await getContractInstanceFromDeployParams(SponsoredFPCContract.artifact, {
        salt: new Fr(SPONSORED_FPC_SALT),
    });
    await pxe.registerContract({
        instance: sponsoredFPC,
        // @ts-ignore
        artifact: SponsoredFPCContract.artifact,
    });
    const contracts = await pxe.getContracts();
    if (!contracts.find(c => c.equals(sponsoredFPC.address))) {
        throw new Error('SponsoredFPC not deployed.');
    }
    return sponsoredFPC;
}
