import fs from 'fs'
import { X509Certificate } from 'crypto'
import { Noir } from '@noir-lang/noir_js'

import {
  OpenBankingDomesticCircuit,
  decodeNoirOutputs,
  generateNoirInputs,
  REVOLUT_JWKS_URI,
  getPubkeyHashes,
  toProverToml,
} from '../src'
import inputs from './test_data/inputs.json'

// hardcoded inputs for now
const payload = fs.readFileSync('./tests/test_data/revolut_payload.txt', 'utf8')
const signature =
  '3e42c30cab535ed5a20dcac4d405004b5098451c72a80b4460b4e3e9a4bc89f131fa6078c1f7de1d740bfd8216e0ea8b67e5d78eaa7897d02902d73c50d3d0e7bbeb4e1b4b6b4d0281bcfb0e029c44f3ea90363e4e1d7ec591e09fc2bdd832428396b054f4f89336df49c01a88bb7e5b5015e706cd179467bf9794a79474884e799fb388050a7fdcaa074225bdc1b856048640e4fb7955a06675649acd89b049b603c0dc32dc5f37796453602f36cc982f86257055162457db6aec9377e7e9fdcb31e4ebce5d6e445c722f0e6a20936bda5c83481b12013078c0cc72551373586dc69db541d729b8d02521a26bb4f42068764438443e9c9164dca039b0fb1176'
const { publicKey } = new X509Certificate(
  fs.readFileSync('./tests/test_data/revolut.cert', 'utf8')
)

const issuingCA = fs.readFileSync(
  './tests/test_data/revolut_issuing_ca.cer',
  'utf8'
)
const rootCA = fs.readFileSync('./tests/test_data/revolut_root_ca.cer', 'utf8')

describe('OpenBanking.nr Circuit Test', () => {
  let noir: Noir

  beforeAll(() => {
    //@ts-ignore
    noir = new Noir(OpenBankingDomesticCircuit)
  })

  describe('Simulate Witnesses', () => {
    it('Test execution', async () => {
      // const inputs = generateNoirInputs(payload, signature, publicKey);
      console.log(toProverToml(inputs.inputs))
      const result = await noir.execute({ params: inputs.inputs })
      const outputs = decodeNoirOutputs(result.returnValue)
      console.log(outputs)

      // expected outputs
      const expectedOutputs = {
        amount: 1, // 1.00 actually
        currencyCode: 'GBP',
        paymentId: '6776972f-e9af-ad6a-8cdd-ff2099bd2475',
        sortCode: '04290953215338',
      }
      expect(outputs).toEqual(expectedOutputs)
    })
    xit('CA', async () => {
      const hashes = await getPubkeyHashes(REVOLUT_JWKS_URI).then((hashes) =>
        hashes.map((hash) => hash.toString())
      )
      const expectedHashes = [
        '0x122fe470d24a14ba2e21e27225df5897b36e91e4ac6f62e022d4b901331b9ade',
        '0x28a4057201b24bfdf7a37dd598077aee7cc969c1f58a3cf6efa28778ba1e35f6',
        '0x0e2c0956cae7472177eb75f5b7228057b0bca4a15d2f97b3416e4b6dbda116c6',
        '0x063b9064814feb22c88e0261a7028adeaec3acd41cb92336c3be712dd1bf0a92',
        '0x1995a9a76e9e03a897b202b27e9a71a7513b733e1a19bbb40cc3f81e2fb2b23f',
      ]
      for (let i = 0; i < hashes.length; i++) {
        expect(hashes[i]).toEqual(expectedHashes[i])
      }
    })
  })
})
