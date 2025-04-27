import { ContractArtifact, ContractBase, NoirCompiledContract } from '@aztec/aztec.js';
import {
    generateVerifyArtifactUrl,
    generateVerifyArtifactPayload,
    generateVerifyInstanceUrl,
    generateVerifyInstancePayload,
    callExplorerApi,
    initialize as initializeExplorerApi,
} from "aztec-scan-sdk";

export const verifySource = async (
    contracts: ContractBase[],
    artifacts: ContractArtifact[]
) => {
    // initialize explorer api
    const apiUrl = "https://api.aztecscan.xyz/v1/";
    const apiKey = "temporary-api-key";
    initializeExplorerApi({ apiUrl, apiKey });

    for (let i = 0; i < contracts.length; i++) {
        const contract = contracts[i];
        const artifact = artifacts[i];
        const classId = contract.instance.currentContractClassId;
        console.log("Class ID: ", classId);
        console.log("Version: ", contract.instance.version);
        // verify contract artifact
        const version = contract.instance.version;
        const artifactUrl = generateVerifyArtifactUrl(undefined, classId.toString(), version);
        const artifactPayload = generateVerifyArtifactPayload(artifact);
        await callExplorerApi({
            urlStr: artifactUrl,
            method: "POST",
            postData: JSON.stringify(artifactPayload),
            loggingString: "Register Artifact",
        });
        let progress = `${i + 1}/${contracts.length}`;
        console.log(`Contract artifact of contract at ${contract.address} verified successfully! (${progress})`);
        // verify deployed instance
    }
}