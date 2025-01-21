// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {CCCPDataStorage as DS, ModuleState, Config} from "../src/lib/CCCPDataStorage.sol";

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
        ModuleState memory state = ModuleState({isDisabled: true, maxValidators: maxValidators});

        DS._setModuleState(moduleId, state);
        ModuleState memory newState = DS._getModuleState(moduleId);

        assertEq(newState.maxValidators, maxValidators);
        assertEq(newState.isDisabled, true);
    }

    function test_OptInOutConfig() public {
        uint64 optInMinDurationBlocks = 123;
        uint64 optOutDelayDurationBlocks = 234;
        uint64 defaultOperatorMaxValidators = 100;
        uint64 defaultBlockGasLimit = 1000000;
        Config memory cfg = Config(
            optInMinDurationBlocks, optOutDelayDurationBlocks, defaultOperatorMaxValidators, defaultBlockGasLimit
        );

        DS._setConfig(cfg);
        Config memory newCfg = DS._getConfig();

        assertEq(newCfg.optInMinDurationBlocks, optInMinDurationBlocks);
        assertEq(newCfg.optOutDelayDurationBlocks, optOutDelayDurationBlocks);
        assertEq(newCfg.defaultOperatorMaxValidators, defaultOperatorMaxValidators);
        assertEq(newCfg.defaultBlockGasLimit, defaultBlockGasLimit);
    }
}
