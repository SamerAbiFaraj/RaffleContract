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
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 playerLength,
        uint256 raffleState
    );

    //* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    // List state variables
    uint16 private constant REQUEST_CONFIRMATIONS = 3; //wait 3 blocks after the vrf request before sending the random number
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee; // if immutable means needs to be set in constructor
    uint256 private s_lastTimeStamp;

    //@dev duration of lottery in seconds
    uint256 private immutable i_interval; // if immutable means needs to be set in constructor
    bytes32 private immutable i_keyHash;
    address payable[] private s_players; //bc who ever wins we will send them the funds
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    //events
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed recentWinner);

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
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // Option1 (old way-Not gas efficient):  require(msg.value >= i_entranceFee, "Not enough ETH to enter raffle!");
        // Option 3 -- best way: but requires higher compiler version and stil uses more gas then the if
        //             require(msg.value >= i_entranceFee, SendMoreToEnterRaffle());

        // Option2 (Still best to us bc most gas efficient):
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));

        // 1. Makes migration easier
        // 2. Makes front end "indexing" easier
        emit RaffleEntered(msg.sender); //You want to emit/event when state variables are updated
    }

    // //**
    //  * @dev This is the function that the chainlink nodes will call to see
    //  * if the lottery is ready to have a winner WinnerPicked.
    //  * The following should be true in order for upkeepNedded to be true;
    //  *  1. time interval have passed between raffle returns
    //  *  2. the lottery is open
    //  *  3. the contract has ETH
    //  *  4. Implicity, your subscription has link
    //  *
    //  * @param - ignored
    //  * @return upkeepNeeded - true if its time to restart the lottery
    //  * @return -- ignored
    //  */

    function checkUpkeep(
        bytes memory /*ckeckData*/
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >=
            i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;

        return (upkeepNeeded, "");
    }

    // 1. Get Random Number
    // 2. Use Random Number to pick a player
    // 3. Be automatically called

    function performUpkeep(bytes memory /* performData */) external {
        //check to see how much time has passed
        // if ((block.timestamp - s_lastTimeStamp) < i_interval) {
        //     //check (current time minus last timestamp) < interval  then we will revert bc lottery not yet over .. else reset lottery
        //     revert();
        // }

        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;
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

        //uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        s_vrfCoordinator.requestRandomWords(request);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }

        emit WinnerPicked(s_recentWinner);
    }

    /**
     * Getter functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }
}
