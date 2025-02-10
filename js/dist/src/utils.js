"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.base64UrlToBytes = base64UrlToBytes;
exports.bytesToBigInt = bytesToBigInt;
exports.toBoundedVec = toBoundedVec;
exports.toProverToml = toProverToml;
exports.u8ToU32 = u8ToU32;
const constants_1 = require("./constants");
function base64UrlToBytes(base64Url) {
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const padding = '='.repeat((4 - (base64.length % 4)) % 4);
    const base64Padded = base64 + padding;
    return Uint8Array.from(atob(base64Padded), (c) => c.charCodeAt(0));
}
function bytesToBigInt(bytes) {
    let hex = Array.from(bytes)
        .map((b) => b.toString(16).padStart(2, '0'))
        .join('');
    return BigInt('0x' + hex);
}
function toBoundedVec(data, maxLength, fillVal = 0) {
    let length = maxLength === undefined ? constants_1.MAX_JWT_SIZE : maxLength;
    if (data.length > length) {
        throw new Error(`Data exceeds maximum length of ${length} bytes`);
    }
    const storage = Array.from(data)
        .concat(Array(length - data.length).fill(fillVal))
        .map((byte) => byte.toString());
    return { storage, len: data.length.toString() };
}
function toProverToml(inputs) {
    const lines = [];
    const structs = [];
    for (const [key, value] of Object.entries(inputs)) {
        if (Array.isArray(value)) {
            const valueStrArr = value.map((val) => `'${val}'`);
            lines.push(`${key} = [${valueStrArr.join(', ')}]`);
        }
        else if (typeof value === 'string') {
            lines.push(`${key} = '${value}'`);
        }
        else {
            let values = '';
            for (const [k, v] of Object.entries(value)) {
                if (Array.isArray(v)) {
                    values = values.concat(`${k} = [${v.map((val) => `'${val}'`).join(', ')}]\n`);
                }
                else {
                    values = values.concat(`${k} = '${v}'\n`);
                }
            }
            structs.push(`[${key}]\n${values}`);
        }
    }
    return lines.concat(structs).join('\n');
}
function u8ToU32(input) {
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
;
