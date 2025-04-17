# Deployment Scripts

There are 3 scripts used for deployments. One is the `deploy.market.s.sol` which is used to deploy a new market. Then there is the `deploy-module.s.sol` which is used to deploy the modules. Finally, `deploy-common-cibtract.s.sol` which is used to deploy contracts common to all markets or standalone contracts. The market script uses the module deployment script to deploy the modules but in a manner such that an EOA can completely deploy the protocol along with module authorizations and hand over control to the owner afterwards.

It's important to note that in case deploying to a new network, first you need to deploy the `OracleModule`. Otherwise, any market deployment will fail. Similarly, any contracts necessary to be deployed before a market deployment should be done so using the `deploy-common-contract.s.sol` script.

The deployment scripts can pick the correct chain to be deployed based on the `--rpc-url` script argument. The `deploy-module.s.sol` script can pick out relevant encoders based on the module name provided when calling the `deployModules` functions.

To deploy a module:
- Add its config in the config file.
- Create an encoder for the module to be deployed in the `encoders` directory. Check the [Encoders.md](./Encoders.md) file for more information.
- Use the bash script provided in the `script/shell` directory. 

To deploy a common contract:
- Add its config in the `CommonContracts.toml` file in a chain specific directory in the `config` directory.
- Create an encoder for the contract to be deployed in the `encoders` directory. Check the [Encoders.md](./Encoders.md) file for more information.
- Use the bash script provided in the `script/shell` directory.

> [!WARNING] If using the `forge` or command directly instead of using the bash script, don't call the `deploy` function directly as it doesn't support transaction broadcasting so you might end up with a transaction which does nothing of note.

## Deploy a Module/Common-Contract
To run a deployment script to deploy a module or a common contract, you can execute the following commands:

For modules

```bash
   script/shell/deploy-modules.sh <CHAIN_ID> <MODE> <MODULE_NAME>...
```

For common contracts

```bash
   script/shell/deploy-common-contracts.sh <CHAIN_ID> <MODE> <CONTRACT_NAME>...
```

- The `CHAIN_ID` is the chain id of the chain you want to deploy on.
- The `MODE` variable executes the script in either `dry` mode where the transactions aren't actually broadcasted and can be used for simulation purposes or `broadcast` mode where the transactions are actually broadcasted. Just enter `dry` or `broadcast` without quotes.
- The `MODULE_NAME` is the name of the module you want to deploy. You can enter multiple module names separated by a space. No need for quotes around the names.

You might be asked for a market id or a tag in case deploying a module. Although most modules are of the 'beacon proxy` type, there could be some which are either immutable or of 'transparent proxy' type. The script cannot differentiate which type of module is being deployed so it asks for a tag regardless.

Once deployed, the module address and related information will be written in the `<CHAIN_ID>.toml` file in the deployments directory. For common contract, the details are in the `CommonContracts.toml` file in the `deployments` folder. This folder is re-written every time a new protocol deployment is done for a chain which was previously deployed on. The `deploy-module.s.sol` will append the new module information into the chain id specific deployments file.

> [!IMPORTANT] The modules are automatically authorized (or a Gnosis Safe transaction is sent) provided the module contracts have the `MODULE_KEY()` function which returns the module key. If there is no such function, the module will not be authorized and the script will warn you in its logs.

## Deploy a Market
To run a deployment script to deploy the protocol, you can execute the following command:

```bash
    script/shell/deploy-market.sh <CHAIN_ID> <MODE>
```

- The `CHAIN_ID` is the chain id of the chain you want to deploy on.
- The `MODE` variable executes the script in either `dry` mode where the transactions aren't actually broadcasted and can be used for simulation purposes or `broadcast` mode where the transactions are actually broadcasted. Just enter `dry` or `broadcast` without quotes.
