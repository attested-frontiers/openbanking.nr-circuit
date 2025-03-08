
import { AztecAddress, createPXEClient, Fr, waitForPXE } from "@aztec/aztec.js"
import { OpenbankingEscrowContract } from "./artifacts"
import { getSingleKeyAccount } from "@aztec/accounts/single_key";

const { PXE_URL } = process.env;

export const addPubkeyHashes = async (adminPrivkey: string, contractAddress: string, keyHashes: string[], pxeUrl: string) => {

    const hashesFr = keyHashes.map(hash => Fr.fromHexString(hash));

    const pxe = createPXEClient(pxeUrl);
    await waitForPXE(pxe);

    const admin = await getSingleKeyAccount(pxe, Fr.fromHexString(adminPrivkey), 0);
    const adminWallet = await admin.waitSetup();

    const escrowContract = await OpenbankingEscrowContract.at(AztecAddress.fromString(contractAddress), adminWallet);

    await escrowContract.methods.add_key_hashes(hashesFr).send().wait();
}

export const revokePubkeyHash = async (adminPrivkey: string, contractAddress: string, keyHashes: string[], pxeUrl: string) => {
    const hashesFr = keyHashes.map(hash => Fr.fromHexString(hash));

    const pxe = createPXEClient(pxeUrl);
    await waitForPXE(pxe);

    const admin = await getSingleKeyAccount(pxe, Fr.fromHexString(adminPrivkey), 0);
    const adminWallet = await admin.waitSetup();

    const escrowContract = await OpenbankingEscrowContract.at(AztecAddress.fromString(contractAddress), adminWallet);

    await escrowContract.methods.add_key_hashes(hashesFr).send().wait();
}