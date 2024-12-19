// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Curator} from "../src/Curator.sol";

contract CuratorCheckScript is Script {
    function run() public {
        vm.startBroadcast();

        address _curatorAddress = 0x5b73C5498c1E3b4dbA84de0F1833c4a029d90519;
        Curator _curator = Curator(_curatorAddress);

        _curator.optIn(0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f, 1, 2, 400, 450);
        _curator.optOut(1, 2);

        vm.stopBroadcast();
    }
}
