import {ethers, providers, Signer, Contract} from 'ethers';

export const ZERO_ADDRESS = `0x${'0'.repeat(40)}`;

type ContractBuild = {
  abi: any;
  bytecode: {
    object: string;
    sourceMap: string;
    linkReferences: {};
  };
};

export const frameSigner = async (
  networkId: string
): Promise<{
  provider: providers.JsonRpcProvider;
  signer: providers.JsonRpcSigner;
}> => {
  const provider = new providers.JsonRpcProvider({
    url: 'http://127.0.0.1:1248',
    headers: {
      Origin: 'http://MyCustomAppName',
    },
    allowInsecureAuthentication: true,
  });

  await provider.send('wallet_switchEthereumChain', [{chainId: networkId}]);

  return {provider, signer: provider.getSigner()};
};

export const deployContract = async ({
  build,
  signer,
  args,
}: {
  build: ContractBuild;
  signer: Signer;
  args: any[];
}): Promise<Contract> => {
  const factory = new ethers.ContractFactory(build.abi, build.bytecode, signer);
  const contract = await factory.deploy(...args);
  await contract.deployed();
  return contract;
};

export const getContract = ({address, abi, signer}) => {
  return new ethers.Contract(address, abi, signer);
};
