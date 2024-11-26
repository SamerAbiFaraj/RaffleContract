//SPDX-License-Identifier:MIT

pragma solidity 0.8.19;

/**
 * @title Raffle contract
 * @author Samer Abi Faraj
 * @notice This contract is for creating a simple raffle
 * @dev Implements Chainlink VRF2.5
 */
contract Raffle {
    uint256 private immutable i_entranceFee;

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() public payable {}

    function pickWinner() public {}

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
