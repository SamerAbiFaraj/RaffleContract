//Laybout Contracts:
// version
// imports
// errors
// interfaces, libraries, contracts
// type declarations
// state variables
// Events
// Modifiers
// Functions

//Layout of Functions:
// constructor
// receive function
// fallback function
// external
// public
// internal
// private
// view and pure functions

//SPDX-License-Identifier:MIT

pragma solidity 0.8.19;

/**
 * @title Raffle contract
 * @author Samer Abi Faraj
 * @notice This contract is for creating a simple raffle
 * @dev Implements Chainlink VRF2.5
 */

//import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
//import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFConsumerBaseV2Plus} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    // errors
    error Raffle__SendMoreToEnterRaffle();

    uint16 private constant REQUEST_CONFIRMATIONS = 3; //wait 3 blocks after the vrf request before sending the random number
    uint32 private constant NUM_WORDS = 1;

    // List state variables
    uint256 private immutable i_entranceFee; // if immutable means needs to be set in constructor
    uint256 private s_lastTimeStamp;

    //@dev duration of lottery in seconds
    uint256 private immutable i_interval; // if immutable means needs to be set in constructor
    bytes32 private immutable i_keyHash;
    address payable[] private s_players; //bc who ever wins we will send them the funds
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    //events
    event RaffleEntered(address indexed player);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() external payable {
        // Option1 (old way-Not gas efficient):  require(msg.value >= i_entranceFee, "Not enough ETH to enter raffle!");
        // Option 3 -- best way: but requires higher compiler version and stil uses more gas then the if
        //             require(msg.value >= i_entranceFee, SendMoreToEnterRaffle());

        // Option2 (Still best to us bc most gas efficient):
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        s_players.push(payable(msg.sender));

        // 1. Makes migration easier
        // 2. Makes front end "indexing" easier
        emit RaffleEntered(msg.sender); //You want to emit/event when state variables are updated
    }

    // 1. Get Random Number
    // 2. Use Random Number to pick a player
    // 3. Be automatically called

    function pickWinner() external {
        //check to see how much time has passed
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            //check (current time minus last timestamp) < interval  then we will revert bc lottery not yet over .. else reset lottery
            revert();
        }
        //Get our random number (version 2.5) from chainlink
        //   1. Request RNG
        //   2. Get RNG

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash, //price will to pay (gas price)
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit, // gas limit
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {}

    /**
     * Getter functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
