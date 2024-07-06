// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {POC} from "src/POC.sol";

contract POCTest is Test {
    uint256 blocknumToForkFrom = 12489619;
    POC public poc;

    function setUp() public {
        vm.createSelectFork("mainnet", blocknumToForkFrom);
        poc = new POC();
    }

    function test_operate() public {
        poc.operate();
    }
}
