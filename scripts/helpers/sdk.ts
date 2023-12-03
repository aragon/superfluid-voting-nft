import {Client, Context, TokenVotingClient} from '@aragon/sdk-client';
import {Wallet, providers} from 'ethers';
const networks = {
  arbitrum: {rpcURL: 'https://rpc.ankr.com/arbitrum'},
  arbitrumGoerli: {rpcURL: 'https://rpc.ankr.com/arbitrum_goerli'},
  sepolia: {rpcURL: 'https://rpc.ankr.com/eth_sepolia'},
  goerli: {rpcURL: 'https://rpc.ankr.com/eth_goerli'},
  mainnet: {rpcURL: 'https://rpc.ankr.com/eth'},
  mumbai: {rpcURL: 'https://rpc.ankr.com/polygon_mumbai'},
  polygon: {rpcURL: 'https://rpc.ankr.com/polygon'},
  baseGoerli: {rpcURL: 'https://rpc.ankr.com/base_goerli'},
  baseMainnet: {rpcURL: 'https://rpc.ankr.com/base_mainnet'},
};

type Network = keyof typeof networks;

type ContextParamsType = {
  network: Network;
  signer?: providers.JsonRpcSigner | Wallet;
};

const contextParams = ({
  network,
  signer = Wallet.createRandom(),
}: ContextParamsType): Context => {
  return new Context({
    network,
    signer,
    web3Providers: [networks[network].rpcURL],
    ipfsNodes: [
      {
        url: 'https://test.ipfs.aragon.network/api/v0',
        headers: {'X-API-KEY': 'b477RhECf8s8sdM7XrkLBs2wHc4kCMwpbcFC55Kt'},
      },
    ],
  });
};

export const client = (params: ContextParamsType) =>
  new Client(contextParams(params));
export const tokenVotingClient = (params: ContextParamsType) =>
  new TokenVotingClient(contextParams(params));
