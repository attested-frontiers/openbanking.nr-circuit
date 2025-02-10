import { BoundedVec } from "./types";
export declare function base64UrlToBytes(base64Url: string): Uint8Array;
export declare function bytesToBigInt(bytes: Uint8Array): bigint;
export declare function toBoundedVec(data: Uint8Array, maxLength: number, fillVal?: number): BoundedVec;
export declare function toProverToml(inputs: Object): string;
export declare function u8ToU32(input: Uint8Array): Uint32Array;
