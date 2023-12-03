import {
  ZERO_ADDRESS,
  deployContract,
  frameSigner,
  getContract,
} from './helpers/ethers';
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

const SuperVotingNFT = getContract({
  address: '0x02527750190bbb8BBD2fb34eE1aC4565934fE30d',
  abi: SuperVotingNFT__Build.abi,
  signer,
});

console.log('SuperVotingNFT: ', SuperVotingNFT.address);
console.log(
  'SuperVotingNFT: ',
  (await SuperVotingNFT.balanceOf(await signer.getAddress())).toString()
);
