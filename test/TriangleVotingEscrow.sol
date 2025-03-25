// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {TriangleVotingEscrow} from "../src/TriangleVotingEscrow.sol";

contract TriangleVotingEscrowTest is Test {
    TriangleVotingEscrow public tve;

    function setUp() public {
        tve = new TriangleVotingEscrow(address(0), 30 days);
    }
}
