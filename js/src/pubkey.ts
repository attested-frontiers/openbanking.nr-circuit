import { Agent } from "https";
import axios from "axios"; // fetch does not respect agent
import { JWK } from "jose";
import { X509Certificate } from 'crypto';
import { generatePubkeyParams } from "./inputGen";
// import { poseidon2Hash } from '@aztec/foundation/crypto';
import { BarretenbergSync, Fr } from "@aztec/bb.js"


export async function getPubkeyHashes(jwksURI: string, issuing?: string, root?: string): Promise<Fr[]> {
    // fetch JWKS
    let agentParams = {};
    if (!issuing || !root) {
        agentParams = { rejectUnauthorized: false };
    } else {
        agentParams = { ca: [root, issuing], rejectUnauthorized: true };
    };
    const agent = new Agent(agentParams);
    const jwksResponse = await axios
        .get(jwksURI, { httpsAgent: agent })
        .then(res => res.data as { keys: JWK[] });
    // parse the x509 URI to retrieve actual pubkeys
    const x5uURIs = jwksResponse.keys.filter(jwk => jwk.x5u !== undefined).map(jwk => jwk.x5u!);
    const pubkeys = await Promise.all(x5uURIs.map(async x5u => {
        return await axios
            .get(x5u, { responseType: 'text', httpsAgent: agent })
            .then(res => new X509Certificate(res.data))
            .then(cert => generatePubkeyParams(cert.publicKey));
    }));

    const x = await Promise.all(x5uURIs.map(async x5u => {
        return await axios
            .get(x5u, { responseType: 'text', httpsAgent: agent })
            .then(res => new X509Certificate(res.data))
    }));

    const api = await BarretenbergSync.initSingleton();
    const pubkeyHashes = pubkeys.map(pubkey => {
        return api.poseidon2Hash(compressPubkeyPreimage(pubkey));
    });

    console.log("pubkeyHashes", pubkeyHashes)
    return pubkeyHashes;
}

// @dev ASSUMES 2048 BIT KEY
export function compressPubkeyPreimage(pubkey: { modulus_limbs: string[], redc_limbs: string[] }): Fr[] {
    const bigints = [...pubkey.modulus_limbs, ...pubkey.redc_limbs].map(limb => BigInt(limb));
    const compressed: Fr[] = [];
    for (let i = 0; i < bigints.length; i += 2) {
        const low = bigints[i];
        const high = i + 1 < bigints.length ? bigints[i + 1] : 0n;
        compressed.push(new Fr((high << 120n) | low));
    }
    return compressed;
}

// export async function hashPubkey(pubkey: { modulus: string[], redc: string[] }): bigint {

// }