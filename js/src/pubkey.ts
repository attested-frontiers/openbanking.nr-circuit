import { Agent } from 'https';
import axios from 'axios'; // fetch does not respect agent
import { JWK } from 'jose';
import { X509Certificate } from 'crypto';
import { BarretenbergSync, Fr } from '@aztec/bb.js';
import { generatePubkeyParams } from './inputGen';
// import { poseidon2Hash } from '@aztec/foundation/crypto';

type StoredPubkey = {
  kid: string;
  hash: string;
}

export async function getPubkeyHashes(
  jwksURI: string,
  issuing?: string,
  root?: string,
): Promise<Fr[]> {
  // fetch JWKS
  let agentParams = {};
  if (!issuing || !root) {
    agentParams = { rejectUnauthorized: false };
  } else {
    agentParams = { ca: [root, issuing], rejectUnauthorized: true };
  }
  const agent = new Agent(agentParams);
  const jwksResponse = await axios
    .get(jwksURI, { httpsAgent: agent })
    .then((res) => res.data as { keys: JWK[] });
  // parse the x509 URI to retrieve actual pubkeys
  const x5uURIs = jwksResponse.keys
    .filter((jwk) => jwk.x5u !== undefined)
    .map((jwk) => jwk.x5u!);
  const pubkeys = await Promise.all(
    x5uURIs.map(async (x5u) => axios
      .get(x5u, { responseType: 'text', httpsAgent: agent })
      .then((res) => new X509Certificate(res.data))
      .then((cert) => generatePubkeyParams(cert.publicKey)))
  );

  const api = await BarretenbergSync.initSingleton();
  const pubkeyHashes = pubkeys.map((pubkey) => api.poseidon2Hash(compressPubkeyPreimage(pubkey)));

  console.log('pubkeyHashes', pubkeyHashes);
  return pubkeyHashes;
}

export async function getUpdatedPubkeyHashes(
  jwksURI: string,
  storedPubkeys: StoredPubkey[],
  issuing?: string,
  root?: string,
): Promise<any> {
  // fetch JWKS
  let agentParams = {};
  if (!issuing || !root) {
    agentParams = { rejectUnauthorized: false };
  } else {
    agentParams = { ca: [root, issuing], rejectUnauthorized: true };
  }
  const agent = new Agent(agentParams);
  const jwksResponse = await axios
    .get(jwksURI, { httpsAgent: agent })
    .then((res) => res.data as { keys: JWK[] });

  // filter out kids already stored
  const newPubkeys = jwksResponse.keys.filter((key: JWK) => !storedPubkeys.find(pubkey => pubkey.kid === key.kid!));

  // parse the x509 URI to retrieve actual pubkeys
  const x5uURIs = newPubkeys
    .filter((jwk) => jwk.kid !== undefined && jwk.x5u !== undefined)
    .map((jwk) => ({ kid: jwk.kid, x5u: jwk.x5u! }));
  const pubkeys = await Promise.all(
    x5uURIs.map(async (x5u) => {
      return axios
        .get(x5u.x5u, { responseType: 'text', httpsAgent: agent })
        .then((res) => new X509Certificate(res.data))
        .then((cert) => ({ kid: x5u.kid, ...generatePubkeyParams(cert.publicKey) }));
    })
  );

  const api = await BarretenbergSync.initSingleton();
  const pubkeyHashes = pubkeys.map(({ kid, ...pubkeyParams }) => ({ kid, hash: api.poseidon2Hash(compressPubkeyPreimage(pubkeyParams)).toString() }));
  return {
    newPubkeys: pubkeyHashes,
    revokedPubkeys: storedPubkeys.filter(
      (pubkey) => !jwksResponse.keys.find(({ kid }) => kid === pubkey.kid)
    )
  };
}

// @dev ASSUMES 2048 BIT KEY
export function compressPubkeyPreimage(pubkey: {
  modulus_limbs: string[]
  redc_limbs: string[]
}): Fr[] {
  const bigints = [...pubkey.modulus_limbs, ...pubkey.redc_limbs].map((limb) => BigInt(limb));
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
