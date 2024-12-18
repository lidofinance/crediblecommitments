// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Curator} from "../src/Curator.sol";

contract CuratorCheckScript is Script {
    function run() public {
        vm.startBroadcast();

        address _curatorAddress = 0xDB259fa7d7f9F68aE3ffC3c748516ba9567a7576;
        Curator _curator = Curator(_curatorAddress);

        _curator.optIn(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720, 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f, 1, 1, 1, 10);

        vm.stopBroadcast();
    }
}
