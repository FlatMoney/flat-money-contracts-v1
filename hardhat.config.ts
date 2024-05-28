import "dotenv/config";

import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-abi-exporter";
import { HardhatUserConfig } from "hardhat/config";

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.20",
        settings: {
            optimizer: {
                enabled: true,
                runs: 500,
            },
            outputSelection: {
                "*": {
                    "*": ["storageLayout"],
                },
            },
            evmVersion: "paris",
        },
    },
    networks: {
        localhost: {
            chainId: 31337,
            url: "http://127.0.0.1:8545",
            timeout: 0,
            accounts: process.env.TESTNET_PRIVATE_KEY
                ? [process.env.TESTNET_PRIVATE_KEY]
                : ["0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"], // Account #0 private key from hardhat node.
        },
        // NOTE: The following configuration uses legacy transactions. For mainnet, change the configuration to use EIP-1559.
        baseSepolia: {
            chainId: 84532,
            url: process.env.BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org",
            accounts: process.env.TESTNET_PRIVATE_KEY ? [process.env.TESTNET_PRIVATE_KEY] : [],
            blockGasLimit: 25000000,
            gasPrice: 2000000000, // 2 gwei
            loggingEnabled: true,
        },
        base: {
            chainId: 8453,
            url: process.env.BASE_RPC_URL || "https://mainnet.base.org/",
            loggingEnabled: true,
        }
    },
    etherscan: {
        // https://hardhat.org/plugins/nomiclabs-hardhat-etherscan.html#multiple-api-keys-and-alternative-block-explorers
        apiKey: {
            baseSepolia: process.env.BASE_ETHERSCAN_API_KEY!,
        },
        customChains: [
            {
                network: "baseSepolia",
                chainId: 84532,
                urls: {
                    apiURL: "https://api-sepolia.basescan.org/api",
                    browserURL: "https://sepolia.basescan.org/",
                },
            },
        ],
    },
    abiExporter: {
        runOnCompile: true,
        clear: true,
        only: ["src/"],
        except: ["src/flattened-contracts"]
    },
};

export default config;
