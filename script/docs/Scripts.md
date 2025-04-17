## About Scripts

We use Foundry scripts due to its DevX as compared to JS/TS scripts. However, Foundry scripts are not as flexible as JS/TS scripts. We have to use shell scripts to run Foundry scripts to abstract certain things like passing arguments to the Foundry scripts. For the shell scripts to be executed, you have to manually provide the necessary permissions. You can do this by running the following command:

```bash
chmod +x script/shell/*.sh
```

To make things easier, the shell script can read the `.env` file for things like chain name, sender address, and wallet type. These variables are usually suffixed with `_<CHAIN_ID>`. For example, if you want to use sender address of `0xabc` for chain with ID 8453, you add `SENDER_ADDRESS_8453` to the `.env` file. The shell script will automatically pick up the value from the `.env` file based on the value of the `CHAIN_ID` you provide as an argument to the script.

The shell scripts are designed to work with `cast` imported private keys. To know more about `cast wallet import` read [this](https://book.getfoundry.sh/reference/cast/cast-wallet-import?highlight=cast%20import#cast-wallet-import) doc. The foundry scripts however can be run by passing the private key directly as an argument but this is not recommended.

To run a shell script, you can use the following command:

```bash
script/shell/<SCRIPT_NAME>.sh <ARGUMENTS>
```

You don't have to go to the `script/shell` directory to run the script. You can run the script from the root directory of the project.

If you don't want to use the shell scripts for any reason, make sure to pass the arguments to the foundry scripts directly and use the `pnpm run:oz` script to run the foundry scripts. The shell scripts are just a convenience wrapper around the foundry scripts. Read the [docs](https://book.getfoundry.sh/reference/forge/forge-script?highlight=forge%20script#forge-script) for the foundry scripts to know more about the arguments they take.