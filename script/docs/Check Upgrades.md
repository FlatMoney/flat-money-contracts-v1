## Check Upgrades Script

The check upgrades script is named as `check-upgrades.s.sol` and can be used to check if the current deployed implementation matches the module source code. This is done by storing the implementation contract's SHA-1 hash in the deployments file and later comparing it with the latest SHA-1 hash of the module source code. If the hashes do not match, the script will generate a new tab in VSCode with the git diff of the current source code and the source code at a particular commit hash (as stored and modified during deployment or upgrade of the module). Note that if the script says that an upgrade may be required, it only means that some aspect of the source code has changed which may even include comments and typo fixes. It does not necessarily mean that the module has to be upgraded. This is the reason a diff is generated to manually check if the changes warrant an upgrade.

To run the script, use the following command:

```bash
script/shell/check-upgrades.sh <CHAIN_ID>
```

Where `<CHAIN_ID>` is the chain id (number) of the network where the module is deployed.

There are a few things to note:

- The script will only work if running in UNIX-like systems (Linux, MacOS, WSL).
- The diff generation will only work if the script is being run in the integrated terminal of VSCode.
- The diff generation will only work if the module source code is stored in a git repository and the path in the git repo is the same as the path in the local filesystem. That is, if the module source code path in the current filesystem has changed, the diff will not be generated as expected.
- The commit hash which has been stored in the deployments file is fetched by calling `git rev-parse HEAD` in the current branch. So if you have deployed a module in the current commit and then made some changes and then run the script, the diff will not be generated as expected (it will create an empty tab in VSCode).