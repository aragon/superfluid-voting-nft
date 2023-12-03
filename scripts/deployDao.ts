import {ZERO_ADDRESS, deployContract, frameSigner} from './helpers/ethers';
import SuperVotingNFT__Build from '../out/SuperVotingNFT.sol/SuperVotingNFT.json';
import {
  DaoCreationSteps,
  DaoMetadata,
  TokenVotingClient,
  TokenVotingPluginInstall,
  VotingMode,
} from '@aragon/sdk-client';

import {client as Client} from './helpers/sdk';

// PARAMS
const NETWORK_ID = '5'; // '11155111'; // Sepolia

// Signer
const {signer} = await frameSigner(NETWORK_ID);
const client = Client({network: 'goerli', signer});

console.log('Signer: ', await signer.getAddress());

// 1. Deploy SuperVotingNFT
const SuperVotingNFT = await deployContract({
  signer,
  build: SuperVotingNFT__Build,
  args: ['SuperVotingNFT', 'SVNFT', ZERO_ADDRESS, 12345, 6789, ZERO_ADDRESS],
});

console.log('SuperVotingNFT: ', SuperVotingNFT.address);

// 2. Deploy TokenVoting DAO
const tokenVotingPluginInstallParams1: TokenVotingPluginInstall = {
  votingSettings: {
    minDuration: 60 * 60 * 24 * 2, // seconds (minimum amount is 3600)
    minParticipation: 0.25, // 25%
    supportThreshold: 0.5, // 50%
    minProposerVotingPower: BigInt('5000'), // default 0
    votingMode: VotingMode.STANDARD, // default standard, other options: EARLY_EXECUTION, VOTE_REPLACEMENT
  },
  useToken: {
    tokenAddress: SuperVotingNFT.address, // contract address of the token to use as the voting token
    wrappedToken: {name: '', symbol: ''},
  },
};

// Creates a TokenVoting plugin client with the parameteres defined above (with an existing token).
const tokenVotingPluginInstallItem1 =
  TokenVotingClient.encoding.getPluginInstallItem(
    tokenVotingPluginInstallParams1,
    'goerli'
  );

const daoMetadata: DaoMetadata = {
  name: 'SuperVotingNFT',
  description: 'This is a description',
  avatar: 'https://app.superfluid.finance/superfluid-logo-light.svg',
  links: [
    {
      name: 'Web site',
      url: 'https://...',
    },
  ],
};

const metadataUri: string = await client.methods.pinMetadata(daoMetadata);
console.log('metadataUri: ', metadataUri);

const steps = client.methods.createDao({
  metadataUri,
  ensSubdomain: 'superdao-' + Math.floor(Math.random() * 1000000),
  plugins: [tokenVotingPluginInstallItem1], // optional, this will determine the plugins installed in your DAO upon creation. 1 is mandatory, more than that is optional based on the DAO's needs.
});

const {
  value: {txHash},
} = await steps.next();
console.log({txHash});

const {
  value: {address: daoAddress, pluginAddresses},
} = await steps.next();
console.log({daoAddress, tokenVotingAddress: pluginAddresses[0]});

console.log('SuperVotingNFT, isTokenPaused: ', await SuperVotingNFT.paused());

const tx = await SuperVotingNFT.setDao(daoAddress);

await tx.wait();

console.log('SuperVotingNFT, isTokenPaused: ', await SuperVotingNFT.paused());
