// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import "./FlatZapper.t.sol";
import "./FlatZapperTokenTransferMethods.t.sol";

abstract contract FlatZapperAllTests is FlatZapperIntegrationTest, FlatZapperTokenTransferMethodsTests {
    function setUp() public virtual override {
        ZapperSetup.setUp();
    }
}
