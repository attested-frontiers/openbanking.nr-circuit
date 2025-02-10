import { KeyObject } from 'crypto';
import { OpenBankingCircuitInputs } from './types';
export declare function generatePubkeyParams(pubkey: KeyObject): {
    modulus_limbs: string[];
    redc_limbs: string[];
};
export declare function generateNoirInputs(payload: string, signature: string, publicKey: KeyObject): OpenBankingCircuitInputs;
