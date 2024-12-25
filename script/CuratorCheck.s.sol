// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Curator} from "../src/Curator.sol";

contract CuratorCheckScript is Script {
    function run() public {
        vm.startBroadcast();

        address _curatorAddress = 0x99aA73dA6309b8eC484eF2C95e96C131C1BBF7a0;
        Curator _curator = Curator(_curatorAddress);

        //_curator.optIn(0xC9aC09D59e4697c3b68063b93c7bc41964690408, "http://test1.com", 3, 8, 10, 15);

        (
            bool isActive,
            address optInAddress,
            string memory rpcURL,
            uint256 moduleId,
            uint256 operatorId,
            uint256 keysRangeStart,
            uint256 keysRangeEnd
        ) = _curator.getOperator(0xC9aC09D59e4697c3b68063b93c7bc41964690408);
        console.log("Is operator active", isActive);
        console.log("Opt in address", optInAddress);
        console.log("RPC URL", rpcURL);
        console.log("Module ID", moduleId);
        console.log("Operator ID", operatorId);
        console.log("Keys range start", keysRangeStart);
        console.log("Keys range end", keysRangeEnd);

        //_curator.optOut(1, 2);

        vm.stopBroadcast();
    }
}
