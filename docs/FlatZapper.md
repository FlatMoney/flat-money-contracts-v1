# FlatZapper - A Convenience Contract to Zap Into Flat Money Protocol

`FlatZapper.sol` aka `Zapper` is a convenience contract that allows users to enter the Flat Money protocol using any asset(s). The contract is designed to be used with dex aggregator swap datas and using custom encoding to swap multiple tokens in a single transaction.

## Use-Cases

1. Swapping one or more tokens to the collateral token and minting UNIT the Flat Money protocol all in a single transaction.
2. Swapping one or more tokens to the collateral token and opening a leverage position in the Flat Money protocol all in a single transaction.

## Features

- **Swaps one or more tokens to the collateral token**. We refer to this as MULTI_IN_SINGLE_OUT swap type.
- **Support for multiple dex aggregators for each swap in a MULTI_IN_SINGLE_OUT swap type**. For example, let's say you want to swap USDC, DAI and WETH to rETH and for USDC and DAI you want to use 1inch and for WETH you want to use Paraswap and swap all tokens in a single transaction. This is possible with the FlatZapper contract.
- **Support for multiple source token transfer methods**. You can use simple allowance based swaps wherein you allow the zapper to take certain amount of source tokens when executing a swap transaction and/or you can use [permit2](https://blog.uniswap.org/permit2-integration-guide) method for source token transfers which will allow you to sign a message to permit transfer of one/more tokens for the zapper to swap. You can also mix and match different allowance types. For example, let's say you want to swap USDC and DAI to rETH and you have already given allowance to the zapper for USDC but you want to use permit2 for DAI and swap them both in the same transaction. This is possible with the FlatZapper contract.
- **Permit2 signature based approvals**. Instead of creating an allowance transaction each time you want to swap a token or using infinite approvals, you can use permit2 method to sign a message to allow the zapper to transfer tokens on your behalf. This is a more easy and secure way of approving token transfers. You can also use permit2 for swapping multiple tokens in a single transaction and you can do so by signing just one message.

## Architecture

The FlatZapper contract inherits the following contracts:

1. **TokenTransferMethods**: Responsible for handling different source token transfer methods like allowance based transfers and permit2 based transfers. Contains logic to execute source token transfers. TokenTransferMethodsStorage is the corresponding ERC7201 compliant contract.
2. **FlatZapperStorage**: Contains the storage variables for the FlatZapper contract. This is ERC7201 compliant.

The FlatZapper contract acts as the external facing contract that interacts with the TokenTransferMethods contract to transfer source token(s). This contract then instructs the deployed instance of the Swapper contract to swap the source token(s) to the collateral token.

## How to Use

The only relevant function for the user in the FlatZapper contract is the following:

```
function zap(SwapperStructs.InOutData calldata swapStruct_, AnnouncementData calldata announcementData_) external
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
> Also read the [Swapper documentation](./Swapper.md) for more information on how to encode the `InOutData` struct.

The `AnnouncementData` struct is defined as follows:

```
struct AnnouncementData {
    DelayedOrderStructs.OrderType orderType;
    bytes data;
}
```

The general flow for `AnnouncementData` encoding is as follows:

1. The `orderType` can be either `DelayedOrderStructs.OrderType.StableDeposit` or `DelayedOrderStructs.OrderType.LeverageOpen`.
   
2. The `data` is either of the structs ABI encoded:
    
    ```
    struct DepositData {
        uint256 minAmountOut;
        uint256 keeperFee;
    }
    
    struct LeverageOpenData {
        uint256 minMargin;
        uint256 additionalSize;
        uint256 maxFillPrice;
        uint256 keeperFee;
    }
    ```

    The `data` field should be ABI encoded with the struct that corresponds to the `orderType` field.

Some things to note:

- The `minAmountOut` field in the `DepositData` struct is the minimum amount of UNIT that the user expects to be minted after the execution of their order announced using the `zap` function. This should be carefully calculated by the caller (or frontend in our case). The calculation is based on the collateral token amount that can be obtained after swapping the source tokens accounting for slippage and keeper fees. In the tests we use the following formula:

    ```
    minAmountOut = 
        (
            stableModProxy.stableDepositQuote(swapStruct.destData.minDestAmount - keeperFee) 
            *
            (100 - DEFAULT_SLIPPAGE) 
            * 
            1e18
        ) 
        /
        100e18;
    ```

    In the tests, the `DEFAULT_SLIPPAGE` is set to 1 which means 1% slippage is accounted for in the calculation. The keeper fee can be obtained from the `KeeperFee` contract (or a mock of it in our tests).

- The `minMargin` field in the `LeverageOpenData` struct is the minimum amount of margin that the user expects to be used to create a leverage position. The margin is what's obtained after the swap of the source tokens. The `minMargin` should account for the amount received in collateral terms after source token swap(s) accounting for slippage and keeper fees. The calculation we use in the tests are as follows:

    ```
    uint256 minMargin = 
        (
            (swapStruct.destData.minDestAmount - keeperFee) 
            * 
            0.995e18
        ) 
        / 
        1e18;
    ```

    Where `0.995e18` is the 0.5% slippage accounted for in the calculation. The keeper fee can be obtained from the `KeeperFee` contract (or a mock of it in our tests). The `keeperFee` is subtracted from the collateral received after all the swaps and this new amount is compared to the `minMargin` to ensure that the user receives the expected margin after the swap. If the collateral received after swap is more than the `minMargin` after accounting for the keeper fees, it's used to open the leverage position and the excess is not returned to the user.

