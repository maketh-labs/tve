// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Triangle Voting Escrow
/// @notice A voting escrow that uses linear vesting tokens to represent voting power.
///
/// @author mansa maker
contract TriangleVotingEscrow {
    address public immutable token;
    uint256 public immutable epochLength;

    mapping(uint256 epoch => uint256) public totalEscrowedAt;
    mapping(address user => mapping(uint256 epoch => uint256)) public escrowedAt;
    mapping(address user => uint256) public balanceOf;

    constructor(address _token, uint256 _epochLength) {
        token = _token;
        epochLength = _epochLength;
    }

    // epochs is the number of full epochs to stake for
    function stake(address user, uint256 amount, uint256 epochs) public {
        uint256 unlocked = calculateUnlocked(user, block.timestamp);
        if (amount > unlocked) {
            IERC20(token).transferFrom(msg.sender, address(this), amount - unlocked);
            balanceOf[user] += amount - unlocked;
        }

        uint256 currentEpoch = block.timestamp / epochLength;

        // Get height of triangle at beginning of current epoch. Should be larger than `amount`, which is the height at the current block timestamp.
        // height / (epochs + 1) * epochLength = amount / lastEpochEnd - block.timestamp
        uint256 lastEpochEnd = (currentEpoch + epochs + 1) * epochLength;
        uint256 height = amount * (epochs + 1) * epochLength / (lastEpochEnd - block.timestamp);

        for (uint256 i = 0; i < epochs + 1; i++) {
            totalEscrowedAt[currentEpoch + i] += height;
            escrowedAt[user][currentEpoch + i] += height;
            height = height * epochs / (epochs + 1);
        }
    }

    // Only works if time is after the start of the first epoch
    function votingPowerOf(address user, uint256 time) public view returns (uint256) {
        return calculateArea(escrowedAt[user], time);
    }

    // Only works if time is after the start of the first epoch
    function globalVotingPower(uint256 time) public view returns (uint256) {
        return calculateArea(totalEscrowedAt, time);
    }

    function calculateArea(mapping(uint256 epoch => uint256) storage e, uint256 time) internal view returns (uint256) {
        uint256 currentEpoch = time / epochLength;
        uint256 height = e[currentEpoch];
        uint256 area = 0;
        while (height > 0) {
            area += height * epochLength;
            height = e[currentEpoch - 1];
            area += height * epochLength;
            currentEpoch += 1;
        }
        return area;
    }

    function withdraw(uint256 amount) public {
        uint256 unlocked = calculateUnlocked(msg.sender, block.timestamp);
        require(amount <= unlocked, "Not enough unlocked");
        IERC20(token).transfer(msg.sender, amount);
        balanceOf[msg.sender] -= amount;
    }

    // Only works if time is after the start of the first epoch
    function calculateUnlocked(address user, uint256 time) public view returns (uint256) {
        uint256 currentEpoch = time / epochLength;
        uint256 left = escrowedAt[user][currentEpoch];
        uint256 right = escrowedAt[user][currentEpoch + 1];

        // find the height within the trapizoid for corresponding time
        uint256 height = (left * ((currentEpoch + 1) * epochLength - time) + right * (currentEpoch * epochLength - time)) / epochLength;
        return balanceOf[user] - height;
    }
}
