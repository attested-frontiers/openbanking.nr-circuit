import { MAX_JWT_SIZE } from './constants.js';
import { BoundedVec } from './types';
import {
  AztecAddress,
  ContractInstanceWithAddress, Fr, getContractInstanceFromDeployParams,
  PXE,
} from '@aztec/aztec.js'
import { SPONSORED_FPC_SALT } from '@aztec/constants';
import { SponsoredFPCContract } from '@aztec/noir-contracts.js/SponsoredFPC';

/**
 * Takes a base64 url string and converts it to bytes
 * 
 * @param base64Url - base64 url string
 * @returns - base64 url as bytes
 */
export function base64UrlToBytes(base64Url: string): Uint8Array {
  const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
  const padding = '='.repeat((4 - (base64.length % 4)) % 4);
  const base64Padded = base64 + padding;
  return Uint8Array.from(atob(base64Padded), (c) => c.charCodeAt(0));
}

/**
 * Takes a byte array and serializes it to a bigint
 * 
 * @param bytes - byte array
 * @returns bigint representation of bytes
 */
export function bytesToBigInt(bytes: Uint8Array): bigint {
  const hex = Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
  return BigInt(`0x${hex}`);
}

/**
 * Turns an Uint8Array into a BoundedVec type for input into a noir circuit
 * 
 * @param data - data passed in to convert to BoundedVec storage
 * @param maxLength - maximum length the BoundedVec can be
 * @param fillVal - value to pad add end of storage past data length
 * @returns - BoundedVed representation of array
 */
export function toBoundedVec(
  data: Uint8Array,
  maxLength: number,
  fillVal: number = 0
): BoundedVec {
  const length = maxLength === undefined ? MAX_JWT_SIZE : maxLength;
  if (data.length > length) {
    throw new Error(`Data exceeds maximum length of ${length} bytes`);
  }
  const storage = Array.from(data)
    .concat(Array(length - data.length).fill(fillVal))
    .map((byte) => byte.toString());
  return { storage, len: data.length.toString() };
}

/**
 * Transforms an Object representation of circuit inputs into TOML format
 * 
 * @param inputs - Circuit inputs in Javascript object format
 * @returns - Inputs in TOML format inside of a string
 */
export function toProverToml(inputs: Object): string {
  const lines = [];
  const structs = [];
  for (const [key, value] of Object.entries(inputs)) {
    if (Array.isArray(value)) {
      const valueStrArr = value.map((val) => `'${val}'`);
      lines.push(`${key} = [${valueStrArr.join(', ')}]`);
    } else if (typeof value === 'string') {
      lines.push(`${key} = '${value}'`);
    } else {
      let values = '';
      for (const [k, v] of Object.entries(value)) {
        if (Array.isArray(v)) {
          values = values.concat(
            `${k} = [${v.map((val) => `'${val}'`).join(', ')}]\n`
          );
        } else {
          values = values.concat(`${k} = '${v}'\n`);
        }
      }
      structs.push(`[${key}]\n${values}`);
    }
  }
  return lines.concat(structs).join('\n');
}

/**
 * Serializes a Uint8Array to a Uint32Array
 * 
 * @param input - a Uint8Array
 * @returns - a Uint32Array
 */
export function u8ToU32(input: Uint8Array): Uint32Array {
  const out = new Uint32Array(input.length / 4);
  for (let i = 0; i < out.length; i++) {
    out[i] =
      (input[i * 4 + 0] << 24) |
      (input[i * 4 + 1] << 16) |
      (input[i * 4 + 2] << 8) |
      (input[i * 4 + 3] << 0);
  }
  return out;
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
