// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import "../Setups/8453.setup.sol";
import "../Common/Swapper/SwapperAllTests.t.sol";
import "../Common/FlatZapper/FlatZapperAllTests.t.sol";

contract SwapperAndZapperAllTests8453 is Setup8453, SwapperAllTests, FlatZapperAllTests {
    function setUp() public virtual override(SwapperAllTests, FlatZapperAllTests, Setup) {
        FlatZapperAllTests.setUp();
    }
}
