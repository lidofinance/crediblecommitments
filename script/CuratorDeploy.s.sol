// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Curator} from "../src/Curator.sol";

contract CuratorDeployScript is Script {
    function run() public {
        vm.startBroadcast();

        address _holeskyStakingRouter = 0xd6EbF043D30A7fe46D1Db32BA90a0A51207FE229;

        Curator _curator = new Curator(_holeskyStakingRouter);

        console.log("Curator address", address(_curator));

        vm.stopBroadcast();
    }
}
