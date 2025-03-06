import {
    createPXEClient,
    Fr,
    waitForPXE,
} from '@aztec/aztec.js';
import { getSingleKeyAccount } from '@aztec/accounts/single_key';
import { TokenContract } from '@aztec/noir-contracts.js/Token';
import { OpenbankingEscrowContract } from './artifacts/contracts/OpenbankingEscrow.js';
// import TokenContractArtifactJson from "@aztec/noir-contracts.js/artifacts/token_contract-Token.json" assert { type: 'json' };

const USDC_TOKEN = {
    symbol: 'USDC',
    name: 'Aztec USDC',
    decimals: 6,
};

const deploy = async () => {
    // const pxe = createPXEClient('https://pxe.obsidion.xyz');
    const pxe = createPXEClient('http://localhost:8080');
    await waitForPXE(pxe);

    // @ts-ignore
    const admin = await getSingleKeyAccount(pxe, Fr.random(), 0);
    const adminWallet = await admin.waitSetup();

    const token = await TokenContract.deploy(
        adminWallet,
        adminWallet.getAddress(),
        USDC_TOKEN.symbol,
        USDC_TOKEN.name,
        USDC_TOKEN.decimals
    )
        .send()
        .deployed();

    const escrow = await OpenbankingEscrowContract.deploy(
        adminWallet,
        token.address,
        [
            Fr.fromHexString(
                '0x122fe470d24a14ba2e21e27225df5897b36e91e4ac6f62e022d4b901331b9ade'
            ),
            Fr.fromHexString(
                '0x28a4057201b24bfdf7a37dd598077aee7cc969c1f58a3cf6efa28778ba1e35f6'
            ),
            Fr.fromHexString(
                '0x0e2c0956cae7472177eb75f5b7228057b0bca4a15d2f97b3416e4b6dbda116c6'
            ),
            Fr.fromHexString(
                '0x063b9064814feb22c88e0261a7028adeaec3acd41cb92336c3be712dd1bf0a92'
            ),
            Fr.fromHexString(
                '0x1995a9a76e9e03a897b202b27e9a71a7513b733e1a19bbb40cc3f81e2fb2b23f'
            ),
        ]
    )
        .send()
        .deployed();

    console.log('Token contract: ', token.address.toString());
    console.log('Escrow contract: ', escrow.address.toString());
    console.log('Token admin: ', adminWallet.getSecretKey().toString());

    // await registerContractClassArtifact(
    //     'EscrowContract',
    //     OpenbankingEscrowArtifactJson as NoirCompiledContract,
    //     escrow.instance.contractClassId.toString(),
    //     1,
    // );
};

deploy();
