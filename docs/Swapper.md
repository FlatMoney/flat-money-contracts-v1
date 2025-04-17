# Swapper - A Contract to Swap Multiple Tokens to a Single Token

`Swapper.sol` aka Swapper is a contract that allows users to swap multiple tokens to a single token. The contract is designed to be used with dex aggregator swap datas and using custom encoding to swap multiple tokens in a single transaction. This contract is supposed to be used for the following use-cases:

### Use-Cases

1. Swapping multiple tokens to a single token in a single transaction on dHEDGE when withdrawing or depositing funds into a vault.
2. Swapping one or more tokens to the collateral token and zapping into the Flat Money protocol. By zap we mean minting UNIT or opening a leverage position.

### Features

- **Swaps one or more tokens to a single token**. This is often referred to as SINGLE_IN_SINGLE_OUT for one token in and one token out and MULTI_IN_SINGLE_OUT for multiple tokens in and one token out.
- **Support for multiple dex aggregators for each swap in a MULTI_IN_SINGLE_OUT swap type**. For example let's say you want to swap USDC, DAI and WETH to rETH and for USDC and DAI you want to use 1inch and for WETH you want to use Paraswap and swap all tokens in a single transaction. This is possible with the Swapper contract.
- **Support for multiple source token transfer methods**. You can use simple allowance based swaps wherein you allow the swapper to take certain amount of source tokens when executing a swap transaction and/or you can use [permit2](https://blog.uniswap.org/permit2-integration-guide) method for source token transfers which will allow you to sign a message to permit transfer of one/more tokens for the Swapper to swap. You can also mix and match different allowance types. For example, let's say you want to swap USDC and DAI to rETH and you have already given allowance to the swapper for USDC but you want to use permit2 for DAI and swap them both in the same transaction. This is possible with the Swapper contract.
- **Permit2 signature based approvals**. Instead of creating an allowance transaction each time you want to swap a token or using infinite approvals, you can use permit2 method to sign a message to allow the Swapper to transfer tokens on your behalf. This is a more easy and secure way of approving token transfers. You can also use permit2 for swapping multiple tokens in a single transaction and you can do so by signing just one message.

### Architecture

The Swapper contract inherit the following contracts:

1. **RouterProcessor**: Responsible for handling dex aggregator swap datas and executing swaps. RouterProcessorStorage is the corresponding ERC7201 compliant contract.
2. **TokenTransferMethods**: Responsible for handling different source token transfer methods like allowance based transfers and permit2 based transfers. Contains logic to execute source token transfers. TokenTransferMethodsStorage is the corresponding ERC7201 compliant contract.

The Swapper contract acts as the external facing contract that interacts with the RouterProcessor and TokenTransferMethods contracts to execute swaps. Users only need to interact with the Swapper contract to execute swaps.

### How to Use

The only relevant function for the user in the Swapper contract is the following:

```
function swap(SwapperStructs.InOutData calldata swapStruct_) external;
```

The `InOutData` struct is defined as follows:

```
struct InOutData {
    SrcData[] srcData;
    DestData destData;
}
```

> [!NOTE]
> All the relevant structs and enums are defined in the `SwapperStructs.sol` file.

The general flow for `InOutData` encoding is as follows:

1. Encode the source token data as the `srcData` array. Each element in the `srcData` array is a `SrcData` struct that contains an array of `SrcTokenSwapDetails` which contains the source token address, the source token amount, the aggregator data required for swapping the source token to destination token, and the transfer method to use for the source tokens in this nested array. `AggregatorData` is a struct that contains the dex aggregator router key which is a bytes32 key that maps to the dex aggregator router address and the swap data which is the encoded swap data for the dex aggregator. Let's take an example below:
  
    ```
    SrcData[] srcData = [
        SrcData({
            srcTokenSwapDetails: [
                SrcTokenSwapDetails({
                    token: USDC,
                    amount: 1000,
                    aggregatorData: AggregatorData({
                        routerKey: bytes32("ONE_INCH"),
                        swapData: 0x1234
                    })
                }),
                SrcTokenDetails({
                    token: DAI,
                    amount: 2000,
                    aggregatorData: AggregatorData({
                        routerKey: bytes32("PARASWAP"),
                        swapData: 0x5678
                    })
                })
            ],
            transferMethod: TransferMethodData({
                method: SwapperStructs.TransferMethod.ALLOWANCE,
                methodData: ""
            })
        }),
        SrcData({
            srcTokenSwapDetails: [
                SrcTokenDetails({
                    token: WETH,
                    amount: 3000,
                    aggregatorData: AggregatorData({
                        routerKey: bytes32("ONE_INCH"),
                        swapData: 0x7890
                    })
                })
            ],
            transferMethodData: TransferMethodData({
                method: SwapperStructs.TransferMethod.PERMIT2,
                methodData: ...
            })
        })
    ];
    ```

    This `srcData` array contains two elements. The first element contains two source tokens USDC and DAI with amounts 1000 and 2000 respectively and the transfer method to use is the simple allowance method which means the user gives allowance to the Swapper contract to transfer these tokens to itself and then process the swaps. This USDC to be swapped should use the 1inch aggregator and the relevant swap data and the DAI to be swapped should use the Paraswap aggregator and its relevant swap data. The second element contains one source token WETH with amount 3000 and the transfer method to use is the permit2 method which means the user signs a message to allow the Swapper to transfer these tokens to itself and then process the swaps.

2. Encode the destination token data as the `destData` struct. The `destData` struct contains the destination token address and the amount to receive. Let's take an example below:

    ```
    DestData destData = DestData({
        token: rETH,
        amount: 6000
    });
    ```

    This `destData` struct contains the destination token rETH with amount 6000.

Some things to keep in mind when encoding the `InOutData` struct:

- The `methodData` in the `TransferMethodData` struct is dependent on the the transfer method used. For example, if you are using the permit2 method then the `methodData` should be the signature of the permit2 message. For simple allowance based transfers the `methodData` should be empty.
- Permit2 related data should be ABI encoded as struct in the `methodData` field. The encoding of the `methodData` should be done as per the struct mentioned below:
    
    ```
    struct Permit2EncodedData {
        Permit2TransferType transferType;
        bytes encodedData;
    }
    ```

    The `Permit2EncodedData` struct should be ABI encoded as a struct and passed as the `methodData` field in the `TransferMethodData` struct. The `encodedData` field in this struct can be ABI encoded as one of the following structs:

    ```
    struct Permit2SingleTransfer {
        ISignatureTransfer.PermitTransferFrom permit;
        ISignatureTransfer.SignatureTransferDetails transferDetails;
        address owner;
        bytes signature;
    }

    struct Permit2BatchTransfer {
        ISignatureTransfer.PermitBatchTransferFrom permit;
        ISignatureTransfer.SignatureTransferDetails[] transferDetails;
        address owner;
        bytes signature;
    }
    ```

    Where the `owner` is the address of the signer of the permit2 message. Rest of the fields can be obtained from the [Uniswap Permit2 SDK](https://github.com/Uniswap/sdks/tree/main/sdks/permit2-sdk/src)
- The `minDestAmount` in the `DestData` struct is the minimum amount of destination tokens that the user expects to receive after the swap. This needs to account for the slippage that the user is willing to tolerate and should be done so by the caller (or the frontend in our case).

### About Integration Tests

The integration tests for the Swapper contract are present in `test/integration/Swapper` directory. These tests rely heavily on the aggregator APIs and swap data fetched from these aggregators. This also means that these tests are dependent on the block number and the state of the blockchain at the time of fetching the data from the aggregator. If you plan to add new tests with new source or destination tokens or amounts, you will have to delete the existing swapdata cache present in `swapdatas-cache` directory and run all the integration tests using command `pnpm test:integration` to fetch the latest swap data from the aggregators and refresh the cache.