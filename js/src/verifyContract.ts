import { createLogger, NoirCompiledContract } from '@aztec/aztec.js';
import { request } from 'https';

// const acir = OpenbankingEscrowContract
// const classId = OpenbankingEscrowContract.
type ArtifactPayload = {
  stringifiedArtifactJson: string
};

export const generateVerifyArtifactPayload = (
  artifactObj: { default: NoirCompiledContract } | NoirCompiledContract
): ArtifactPayload => {
  const artifactJson = (artifactObj as { default: NoirCompiledContract })
    .default
    ? (artifactObj as { default: NoirCompiledContract }).default
    : artifactObj;
  const stringifiedArtifactJson = JSON.stringify(artifactJson);
  return {
    stringifiedArtifactJson,
  };
};

export const generateVerifyArtifactUrl = (
  apiBaseUrl: string,
  contractClassId: string,
  version: number
) => `${apiBaseUrl}/l2/contract-classes/${contractClassId}/versions/${version}`;

export const registerContractClassArtifact = async (
  contractLoggingName: string,
  artifactObj: { default: NoirCompiledContract } | NoirCompiledContract,
  contractClassId: string,
  version: number,
  skipSleep = false
) => {
  const apiBaseUrl = 'https://api.devnet.aztecscan.xyz/v1/temporary-api-key';
  const logger = createLogger('aztec:aztec-starter');

  const url = `${apiBaseUrl}/l2/contract-classes/${contractClassId}/versions/${version}`;
  const postData = JSON.stringify(generateVerifyArtifactPayload(artifactObj));

  const sizeInMB = Buffer.byteLength(postData) / 1000 ** 2;
  if (sizeInMB > 10) {
    logger.warn(
      `🚨📜 ${contractLoggingName} Artifact is too large to register in explorer-api: ${url} (byte length: ${sizeInMB} MB)`
    );
    return;
  }
  logger.info(
    `📜 ${contractLoggingName} Trying to register artifact in explorer-api: ${url} (byte length: ${sizeInMB} MB)`
  );
  if (!skipSleep) await new Promise((resolve) => setTimeout(resolve, 1000));

  const res: {
    statusCode: number | undefined
    statusMessage: string | undefined
    data: string
  } = await new Promise((resolve, reject) => {
    const req = request(
      url,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => {
          data += chunk;
        });
        res.on('end', () => {
          resolve({
            statusCode: res.statusCode,
            statusMessage: res.statusMessage,
            data,
          });
        });
        // get the status code
      }
    );
    req.on('error', (error) => {
      logger.error(`🚨📜 ${contractLoggingName} Artifact registration failed.`);
      reject(error);
    });

    // Set a timeout (e.g., 5 seconds)
    req.setTimeout(5000, () => {
      reject(new Error('Request timed out'));
    });

    req.write(postData);
    req.end(); // This actually sends the request
  });
  if (res.statusCode === 200 || res.statusCode === 201) {
    logger.info(
      `📜✅ ${contractLoggingName} Artifact registered in explorer-api. ${JSON.stringify(
        {
          statusCode: res.statusCode,
          statusMessage: res.statusMessage,
        }
      )}`
    );
  } else {
    logger.error(
      `📜🚨 ${contractLoggingName} Artifact registration failed. ${JSON.stringify(
        {
          statusCode: res.statusCode,
          statusMessage: res.statusMessage,
          data: res.data,
        }
      )}`
    );
  }
};

// await registerContractClassArtifact(
//     'EscrowContract',
//     OpenbankingEscrowArtifactJson as NoirCompiledContract,
//     '0x2a8998ed7b5066f41e0d3d5add8da653c99421b779dd6b6067f6cc55d8f7c255',
//     1,
// );

// await registerContractClassArtifact(
//     'EscrowContract',
//     OpenbankingEscrowArtifactJson as NoirCompiledContract,
//     '0x2b6c6c62c461584e00fe5479697331292605b0399c3824c01b8f340e80d38f20',
//     1,
// );
