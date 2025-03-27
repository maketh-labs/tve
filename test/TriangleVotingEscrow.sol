// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {TriangleVotingEscrow} from "../src/TriangleVotingEscrow.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TriangleVotingEscrowTest is Test {
    ERC20Mock public token;
    TriangleVotingEscrow public tve;
    address public user;

    function setUp() public {
        token = new ERC20Mock();
        tve = new TriangleVotingEscrow(address(token), 30 days);
        user = makeAddr("user");

        token.mint(user, 1000 ether);
        vm.prank(user);
        token.approve(address(tve), 1000 ether);

        vm.warp(45 days);
    }

    function test_interpolateHeight() public {
        assertEq(tve.interpolateHeight(1000 ether, 0, 30 days, 0), 1000 ether, "start at 1000 ether");
        assertEq(tve.interpolateHeight(1000 ether, 0, 30 days, 6 days), 800 ether, "200 ether at 6 days");
        assertEq(tve.interpolateHeight(1000 ether, 0, 30 days, 12 days), 600 ether, "400 ether at 12 days");
        assertEq(tve.interpolateHeight(1000 ether, 0, 30 days, 15 days), 500 ether, "500 ether at 15 days");
        assertEq(tve.interpolateHeight(1000 ether, 0, 30 days, 18 days), 400 ether, "400 ether at 18 days");
        assertEq(tve.interpolateHeight(1000 ether, 0, 30 days, 24 days), 200 ether, "200 ether at 24 days");
        assertEq(tve.interpolateHeight(1000 ether, 0, 30 days, 30 days), 0 ether, "0 ether at 30 days");
    }

    function test_vest() public {
        vm.prank(user);
        tve.vest(user, 1000 ether, 0);

        // Sanity check
        assertEq(token.balanceOf(user), 0, "user should have 0 balance");
        assertEq(token.balanceOf(address(tve)), 1000 ether, "tve should have 1000 ether");

        // Check voting power
        assertEq(tve.balanceOf(user), 1000 ether, "user should have 1000 ether");
        assertEq(tve.totalEscrowedAt(1), 1000 ether * 2, "totalEscrowedAt should be 1000 ether");
        assertEq(tve.escrowedAt(user, 1), 1000 ether * 2, "escrowedAt should be 1000 ether");
        assertEq(tve.votingPowerOf(user, block.timestamp), 1000 ether * 15 days / 2, "votingPower");
    }

    function test_extend() public {
        vm.prank(user);
        tve.vest(user, 1000 ether, 0);

        vm.prank(user);
        tve.extend(3); // day 90

        uint256 y_intercept = 1000 ether * 4 / uint256(3);

        assertEq(tve.totalEscrowedAt(1), y_intercept, "totalEscrowedAt 1");
        assertEq(tve.totalEscrowedAt(2), y_intercept / 2, "totalEscrowedAt 2");
        assertEq(tve.totalEscrowedAt(3), 0, "totalEscrowedAt 3");
        assertEq(tve.escrowedAt(user, 1), y_intercept, "escrowedAt 1");
        assertEq(tve.escrowedAt(user, 2), y_intercept / 2, "escrowedAt 2");
        assertEq(tve.escrowedAt(user, 3), 0, "escrowedAt 3");

        // Just assert if they are close enough.
        assertLe(tve.votingPowerOf(user, block.timestamp) * 1000 / (1000 ether * 45 days / 2), 1001, "votingPower");
        assertGe(tve.votingPowerOf(user, block.timestamp) * 1000 / (1000 ether * 45 days / 2), 999, "votingPower");
    }
}
