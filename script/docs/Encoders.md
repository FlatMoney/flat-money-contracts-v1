# Encoders

The encoder files present in the `../deployment/encoders` directory are used to create encoded calldata to be passed to the deployment script. Each module requires an encoder. These are necessary because deployment using OZ Foundry Upgrades plugin requires the calldata for a function call (in most cases call to the `initialize` function) to be encoded.

The encoders read the config file for a particular chain and module and use the information to encode the calldata. The encoder contracts should be able to read the config TOML files and it's the responsibility of the dev writing the encoder to make sure that the values read from the config are appropriately type coerced. The deployment script automatically picks the correct encoder based on the chain and module provided certain conventions are followed. These are:

 - The encoder file should be named as `<module_name>.encoder.sol`
 - The encoder contract should be names as `<module_name>Encoder`
  
### Index File

You might have noticed that there is an `Index.sol` file in the `encoders` directory. This file is used to import all the encoder contracts and is required for the tasks to work. It wasn't required earlier but due to some changes in the way Foundry works, the files unless imported in the script file, are not picked by the compiler for compilation and hence the encoder contracts are not available for the scripts to use.

To be more technical, we use the [deployCode](https://book.getfoundry.sh/reference/forge-std/deployCode?highlight=deployCode#deploycode) cheat to deploy the encoder contract corresponding to the module/contract to be deployed. However, the cheat requires the contract to be deployed to have its compilation artifacts present in the `out` directory (the default artifacts directory in Foundry). The contracts are compiled only if they are imported in the script file. Hence, the `index.sol` file is required to import all the encoder contracts so that they are compiled and their artifacts are available for the deployment script to use.
 