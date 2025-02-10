import fs from 'fs';
import { X509Certificate } from 'crypto';
import { Noir } from '@noir-lang/noir_js';

import {
  OpenBankingDomesticCircuit,
  generateNoirInputs,
} from '../src';

// hardcoded inputs for now
const payload = fs.readFileSync('./tests/test_data/revolut_payload.txt', 'utf8');
const signature =
  '3e42c30cab535ed5a20dcac4d405004b5098451c72a80b4460b4e3e9a4bc89f131fa6078c1f7de1d740bfd8216e0ea8b67e5d78eaa7897d02902d73c50d3d0e7bbeb4e1b4b6b4d0281bcfb0e029c44f3ea90363e4e1d7ec591e09fc2bdd832428396b054f4f89336df49c01a88bb7e5b5015e706cd179467bf9794a79474884e799fb388050a7fdcaa074225bdc1b856048640e4fb7955a06675649acd89b049b603c0dc32dc5f37796453602f36cc982f86257055162457db6aec9377e7e9fdcb31e4ebce5d6e445c722f0e6a20936bda5c83481b12013078c0cc72551373586dc69db541d729b8d02521a26bb4f42068764438443e9c9164dca039b0fb1176';
const { publicKey } = new X509Certificate(fs.readFileSync('./tests/test_data/revolut.cert', 'utf8'));


describe('OpenBanking.nr Circuit Test', () => {
  let noir: Noir

  beforeAll(() => {
    //@ts-ignore
    noir = new Noir(OpenBankingDomesticCircuit);
  });

  describe('Simulate Witnesses', () => {
    it('Test execution', async () => {
      const inputs = generateNoirInputs(payload, signature, publicKey);
      const result = await noir.execute({params: inputs });
      console.log("result", result);
      expect(result).toBeDefined();
    });
  });
});