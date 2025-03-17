import { Agent } from 'https';
import axios from 'axios'; // fetch does not respect agent
import { JWK } from 'jose';
import { X509Certificate } from 'crypto';
import { BarretenbergSync, Fr } from '@aztec/bb.js';
import { generatePubkeyParams } from './inputGen';

type StoredPubkey = {
  kid: string;
  hash: string;
}

/**
 * Gets a list of valid Openbanking pubkeys
 * 
 * @param jwksURI - URL that returns a list of valid pubkeys to verify Openbanking payments
 * @param issuing - issuing certificate for User Agent
 * @param root - root certiface for User Agent
 * @returns - list of valid pubkeys
 */
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

  return pubkeyHashes;
}

/**
 * Helper function for the Openbanking.nr server that fetches new pubkey hashes that have not
 * been stored
 * 
 * @param jwksURI - URL that returns a list of valid pubkeys to verify Openbanking payments
 * @param storedPubkeys - pubkeys that have already been stored inside of server database
 * @param issuing - issuing certificate for User Agent
 * @param root - root certificate for User Agent
 * @returns - New pubkeys that need to be added to DB and revoked pubkeys that need to be removed
 */
export async function getUpdatedPubkeyHashes(
  jwksURI: string,
  storedPubkeys: StoredPubkey[],
  issuing?: string,
  root?: string,
): Promise<{ newPubkeys: StoredPubkey[], revokedPubkeys: StoredPubkey[] }> {
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
  const pubkeyHashes = pubkeys.map(({ kid, ...pubkeyParams }) => ({ kid: kid ?? '', hash: api.poseidon2Hash(compressPubkeyPreimage(pubkeyParams)).toString() }));
  return {
    newPubkeys: pubkeyHashes,
    revokedPubkeys: storedPubkeys.filter(
      (pubkey) => !jwksResponse.keys.find(({ kid }) => kid === pubkey.kid)
    )
  };
}

// @dev ASSUMES 2048 BIT KEY
/**
 * Takes pubkey in modulus / redc limb format and compresses it into an Fr
 * 
 * @param pubkey - Pubkey in limb format
 * @returns - compressed pubkey
 */
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
