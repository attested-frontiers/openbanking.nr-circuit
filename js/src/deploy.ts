import {
  AccountWalletWithSecretKey,
  createPXEClient,
  Fq,
  Fr,
  PXE,
  waitForPXE,
} from '@aztec/aztec.js';
import { getSingleKeyAccount } from '@aztec/accounts/single_key';

const deploy = async () => {
  const fq = Fq.fromHexString(
    '0x082e6d118b06b9fb3bf5bcaa5328f6f742c86dad8df04d5601c3508c827d3c38'
  );
  const fr = Fr.fromHexString(
    '0x06ef861b5853f12549a8d7e3e67083ae680123dcbb12cedb6d3060075f9d0b3c'
  );

  const pxe = createPXEClient('http://localhost:8080');
  await waitForPXE(pxe);

  // @ts-ignore
  const admin = getSingleKeyAccount(pxe, fr);
  const adminWallet = await admin.waitSetup();
  console.log('Wallet: ', adminWallet);
};

deploy();
