// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {CCCPDataStorage as DS, ModuleState, OptInOutConfig} from "../src/lib/CCCPDataStorage.sol";

contract ModulesDataStorageTest is Test {
    function setUp() public {
        // counter.setNumber(0);
    }

    function test_StorageLocationConstant() public pure {
        bytes32 location = keccak256(abi.encode(uint256(keccak256("lido.cccp.CCCPData")) - 1)) & ~bytes32(uint256(0xff));

        assertEq(DS.CCCP_DATA_LOCATION, location);
    }

    function test_ModuleState() public {
        uint24 moduleId = 111;
        uint64 maxValidators = 1111;
        ModuleState memory state = ModuleState({isActive: true, maxValidators: maxValidators});

        DS._setModuleState(moduleId, state);
        ModuleState memory newState = DS._getModuleState(moduleId);

        assertEq(newState.maxValidators, maxValidators);
        assertEq(newState.isActive, true);
    }

    function test_OptInOutConfig() public {
        uint64 optInMinDurationBlocks = 123;
        uint64 optOutDelayDurationBlocks = 234;
        OptInOutConfig memory cfg = OptInOutConfig(optInMinDurationBlocks, optOutDelayDurationBlocks);

        DS._setConfigOptInOut(cfg);
        OptInOutConfig memory newCfg = DS._getConfigOptInOut();

        assertEq(newCfg.optInMinDurationBlocks, optInMinDurationBlocks);
        assertEq(newCfg.optOutDelayDurationBlocks, optOutDelayDurationBlocks);
    }

    // function testFuzz_SetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}
