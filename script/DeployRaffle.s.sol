//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";

//import {HelperConfig} from "./HelperConfig.sol";

contract DeployRaffle is Script {
    function run() public {}

    function deployContract() external returns (Raffle, HelperConfig) {}
}
