// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {CCCPConfigStorage} from "../src/lib/CCCPConfigStorage.sol";

contract ModulesDataStorageTest is Test, CCCPConfigStorage {
    function setUp() public {}

    function test_ModuleConfig() public {
        uint24 moduleId = 111;
        uint64 maxValidators = 1111;

        _setModuleConfig(moduleId, maxValidators, true);
        (uint64 newMaxValidators, bool newIsDisabled) = _getModuleConfig(moduleId);

        assertEq(newMaxValidators, maxValidators);
        assertEq(newIsDisabled, true);
    }

    function test_Config() public {
        uint64 optInMinDurationBlocks = 123;
        uint64 optOutDelayDurationBlocks = 234;
        uint64 defaultOperatorMaxValidators = 100;
        uint64 defaultBlockGasLimit = 1000000;

        _setConfig(
            optInMinDurationBlocks, optOutDelayDurationBlocks, defaultOperatorMaxValidators, defaultBlockGasLimit
        );
        (
            uint64 newOptInMinDurationBlocks,
            uint64 newOptOutDelayDurationBlocks,
            uint64 newDefaultOperatorMaxValidators,
            uint64 newDefaultBlockGasLimit
        ) = _getConfig();

        assertEq(newOptInMinDurationBlocks, optInMinDurationBlocks);
        assertEq(newOptOutDelayDurationBlocks, optOutDelayDurationBlocks);
        assertEq(newDefaultOperatorMaxValidators, defaultOperatorMaxValidators);
        assertEq(newDefaultBlockGasLimit, defaultBlockGasLimit);
    }
}
