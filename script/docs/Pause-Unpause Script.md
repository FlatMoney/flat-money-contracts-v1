# Pause and Unpause Modules

There is a bash script to help in pausing and unpausing modules. The script is located in the `script/shell` directory and is named `pause-unpause-modules.sh`. The script can be run as follows:

```bash
    script/shell/pause-unpause-modules.sh <CHAIN_ID> <ACTION> <MODE> <GAS_PRICE?> <MODULE_NAME>...
```

- The `CHAIN_ID` is the chain id of the chain you want to pause/unpause the module on.
- The `ACTION` variable is the action you want to perform. You can enter either `pause` or `unpause` without quotes.
- The `MODE` variable executes the script in either `dry` mode where the transactions aren't actually broadcasted and can be used for simulation purposes or `broadcast` mode where the transactions are actually broadcasted. Just enter `dry` or `broadcast` without quotes.
- The `GAS_PRICE` is an optional field depending on the `MODE`. You should not mention any value if you are running in `dry` mode. If you are running in `broadcast` mode, you should mention the gas price you want to use for the transactions without the `gwei` suffix. For example, if you want to use a gas price of 100 gwei, you would enter `100`.
- The `MODULE_NAME` is the name of the module you want to pause/unpause. You can enter multiple module names separated by a space. No need for quotes around the names.
  
You can either pause or unpause all modules mentioned as arguments while running the script. You can't mix and match pause and unpause in a single run of the script. The `pause-unpause-module.s.sol` script assumes that the module name being passed in the arguments contains the `MODULE_KEY()` function which returns the module key. If there is no such function, the script will warn you in its logs.
