import { MAX_JWT_SIZE } from './constants';
import { BoundedVec } from './types';

export function base64UrlToBytes(base64Url: string): Uint8Array {
  const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
  const padding = '='.repeat((4 - (base64.length % 4)) % 4);
  const base64Padded = base64 + padding;
  return Uint8Array.from(atob(base64Padded), (c) => c.charCodeAt(0));
}

export function bytesToBigInt(bytes: Uint8Array): bigint {
  const hex = Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
  return BigInt(`0x${hex}`);
}

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
