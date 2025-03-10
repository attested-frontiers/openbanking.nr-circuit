
import { AztecAddress, createPXEClient, Fr, waitForPXE } from "@aztec/aztec.js"
import { OpenbankingEscrowContract } from "./artifacts"
import { getSingleKeyAccount } from "@aztec/accounts/single_key";

export const addPubkeyHashes = async (adminPrivkey: string, contractAddress: string, pxeUrl: string, keyHashes: string[]) => {

    const pxe = createPXEClient(pxeUrl);
    await waitForPXE(pxe);

    const admin = await getSingleKeyAccount(pxe, Fr.fromHexString(adminPrivkey), 0);
    const adminWallet = await admin.waitSetup();

    const escrowContract = await OpenbankingEscrowContract.at(AztecAddress.fromString(contractAddress), adminWallet);

    for (let i = 0; i < keyHashes.length; i += 4) {
        const chunk = [Fr.ZERO, Fr.ZERO, Fr.ZERO, Fr.ZERO]
        for (let j = 0; j < 4; j++) {
            if (j + i < keyHashes.length) {
                chunk[j] = Fr.fromHexString(keyHashes[j + i])
            }
        }
        if (keyHashes.length) {
            escrowContract.methods.add_key_hashes(chunk).send()
        }
    }
}

export const revokePubkeyHashes = async (adminPrivkey: string, contractAddress: string, pxeUrl: string, keyHashes: string[]) => {
    const pxe = createPXEClient(pxeUrl);
    await waitForPXE(pxe);

    const admin = await getSingleKeyAccount(pxe, Fr.fromHexString(adminPrivkey), 0);
    const adminWallet = await admin.waitSetup();

    const escrowContract = await OpenbankingEscrowContract.at(AztecAddress.fromString(contractAddress), adminWallet);

    for (let i = 0; i < keyHashes.length; i += 4) {
        const chunk = [Fr.ZERO, Fr.ZERO, Fr.ZERO, Fr.ZERO]
        for (let j = 0; j < 4; j++) {
            if (j + i < keyHashes.length) {
                chunk[j] = Fr.fromHexString(keyHashes[j + i])
            }
        }
        if (keyHashes.length) {
            escrowContract.methods.revoke_keys(chunk).send()
        }
    }
}