// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Curator} from "../src/Curator.sol";

contract CuratorDeployScript is Script {
    function run() public {
        vm.startBroadcast();

        address _holeskyStakingRouter = 0xd6EbF043D30A7fe46D1Db32BA90a0A51207FE229;

        // @todo Insert real address here once manager multisig is set up
        address _managerAddress = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

        Curator _curator = new Curator(_holeskyStakingRouter, _managerAddress);

        console.log("Curator address", address(_curator));

        vm.stopBroadcast();
    }
}
