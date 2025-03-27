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
    function vest(address user, uint256 amount, uint256 epochs) public {
        uint256 currentEpoch = block.timestamp / epochLength;

        // Check if we need to transfer additional tokens
        uint256 unlocked = unlockedAt(user, block.timestamp);
        if (amount > unlocked) {
            IERC20(token).transferFrom(msg.sender, address(this), amount - unlocked);
            balanceOf[user] += amount - unlocked;
        }

        // Calculate initial height of triangle
        uint256 lastEpochEnd = (currentEpoch + epochs + 1) * epochLength;
        uint256 height = amount * (epochs + 1) * epochLength / (lastEpochEnd - block.timestamp);

        // Update escrow records for each epoch
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
        uint256 epoch = time / epochLength;
        uint256 currentTimeInEpoch = time % epochLength;

        uint256 left = e[epoch];
        uint256 right = e[epoch + 1];

        // Calculate area of current partial epoch
        uint256 currentHeight = interpolateHeight(left, right, epochLength, currentTimeInEpoch);
        uint256 area = (currentHeight + right) * (epochLength - currentTimeInEpoch) / 2;

        // Add areas of future epochs
        while (right > 0) {
            epoch++;
            left = right;
            right = e[epoch + 1];
            area += (left + right) * epochLength / 2;
        }

        return area;
    }

    function unlockedAt(address user, uint256 time) public view returns (uint256) {
        uint256 currentEpoch = time / epochLength;
        uint256 balance = balanceOf[user];
        uint256 height = interpolateHeight(
            escrowedAt[user][currentEpoch], escrowedAt[user][currentEpoch + 1], epochLength, time % epochLength
        );
        return balance - height;
    }

    function claim(uint256 amount) public {
        uint256 unlocked = unlockedAt(msg.sender, block.timestamp);
        require(amount <= unlocked, "Not enough unlocked");
        IERC20(token).transfer(msg.sender, amount);
        balanceOf[msg.sender] -= amount;
    }

    function claimAll() public {
        uint256 unlocked = unlockedAt(msg.sender, block.timestamp);
        require(unlocked > 0, "None unlocked");
        IERC20(token).transfer(msg.sender, unlocked);
        balanceOf[msg.sender] -= unlocked;
    }

    /**
     * @notice Calculates the height of a line within a trapezoid using linear interpolation
     * @param leftHeight Height of the left side of the trapezoid
     * @param rightHeight Height of the right side of the trapezoid
     * @param totalWidth Total width of the trapezoid (time period)
     * @param currentPosition Current position within the trapezoid (current time)
     * @return Height of the interpolated line at the current position
     */
    function interpolateHeight(uint256 leftHeight, uint256 rightHeight, uint256 totalWidth, uint256 currentPosition)
        public
        pure
        returns (uint256)
    {
        // Linear interpolation formula:
        // height = leftHeight + (rightHeight - leftHeight) * (currentPosition / totalWidth)
        // This can be rearranged to avoid floating point:
        // height = (leftHeight * (totalWidth - currentPosition) + rightHeight * currentPosition) / totalWidth
        return (leftHeight * (totalWidth - currentPosition) + rightHeight * currentPosition) / totalWidth;
    }
}
