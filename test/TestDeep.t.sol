// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LiquidationDeep} from "src/LiquidationDeep.sol";

contract LiquidationOperatorTest is Test {
    uint256 blocknumToForkFrom = 12489619;
    LiquidationDeep public liquidationDeep;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        liquidationDeep = new LiquidationDeep();
    }

    function test_operate_deep() public {
        liquidationDeep.operate();
    }
}
