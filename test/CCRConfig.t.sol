// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {CCRCommon} from "./helpers/CCRCommon.sol";

import {CCR} from "../src/CCR.sol";
import {IStakingRouter} from "test/helpers/mocks/StakingRouterMock.sol";
import {ICCRConfigStorage} from "../src/interfaces/ICCRConfigStorage.sol";

contract CCRConfig is CCRCommon {
    CCR public ccr;
    uint24 public moduleId = 1;
    uint64 public maxKeys = 1111;
    uint64 public blockGasLimit = 1111111;

    uint64 constant optInDelayBlocks = 32;
    uint64 constant optOutDelayBlocks = 64;
    uint64 constant defaultOperatorMaxKeys = 100;
    uint64 constant defaultBlockGasLimit = 1000000;

    function setUp() public virtual override {
        super.setUp();

        ccr = new CCR(address(locator), "community-onchain-v1");
        _enableInitializers(address(ccr));
        ccr.initialize({
            committeeAddress: committee,
            optInDelayBlocks: optInDelayBlocks,
            optOutDelayBlocks: optOutDelayBlocks,
            defaultOperatorMaxKeys: defaultOperatorMaxKeys,
            defaultBlockGasLimit: defaultBlockGasLimit
        });
    }

    function test_GetInitialConfig() public view {
        (
            uint64 newoptInDelayBlocks,
            uint64 newoptOutDelayBlocks,
            uint64 newDefaultOperatorMaxKeys,
            uint64 newDefaultBlockGasLimit
        ) = ccr.getConfig();

        assertEq(newoptInDelayBlocks, optInDelayBlocks);
        assertEq(newoptOutDelayBlocks, optOutDelayBlocks);
        assertEq(newDefaultOperatorMaxKeys, defaultOperatorMaxKeys);
        assertEq(newDefaultBlockGasLimit, defaultBlockGasLimit);
    }

    function test_SetConfig() public {
        vm.prank(committee);
        ccr.setConfig(10, 20, 30, 40);
        (
            uint64 newoptInDelayBlocks,
            uint64 newoptOutDelayBlocks,
            uint64 newDefaultOperatorMaxKeys,
            uint64 newDefaultBlockGasLimit
        ) = ccr.getConfig();

        assertEq(newoptInDelayBlocks, 10);
        assertEq(newoptOutDelayBlocks, 20);
        assertEq(newDefaultOperatorMaxKeys, 30);
        assertEq(newDefaultBlockGasLimit, 40);
    }

    function test_SetConfig_RevertWhen_CallerNotCommittee() public {
        bytes32 role = ccr.COMMITTEE_ROLE();

        vm.prank(stranger1);
        expectRoleRevert(stranger1, role);
        ccr.setConfig(optInDelayBlocks, optOutDelayBlocks, defaultOperatorMaxKeys, defaultBlockGasLimit);
    }

    function test_SetConfig_RevertWhen_ZeroDefaultOperatorMaxKeys() public {
        vm.prank(committee);
        vm.expectRevert(ICCRConfigStorage.ZeroDefaultOperatorMaxKeys.selector);
        ccr.setConfig(optInDelayBlocks, optOutDelayBlocks, 0, defaultBlockGasLimit);
    }

    function test_SetConfig_RevertWhen_ZeroDefaultBlockGasLimit() public {
        vm.prank(committee);
        vm.expectRevert(ICCRConfigStorage.ZeroDefaultBlockGasLimit.selector);
        ccr.setConfig(optInDelayBlocks, optOutDelayBlocks, defaultOperatorMaxKeys, 0);
    }

    function test_SetModuleConfig() public {
        vm.prank(committee);
        ccr.setModuleConfig(moduleId, true, maxKeys, blockGasLimit);
        (bool newIsDisabled, uint64 newMaxKeys, uint64 newblockGasLimit) = ccr.getModuleConfig(moduleId);

        assertEq(newIsDisabled, true);
        assertEq(newMaxKeys, maxKeys);
        assertEq(newblockGasLimit, blockGasLimit);
    }

    function test_SetModuleConfig_RevertWhen_CallerNotCommittee() public {
        bytes32 role = ccr.COMMITTEE_ROLE();

        vm.prank(stranger1);
        expectRoleRevert(stranger1, role);
        ccr.setModuleConfig(moduleId, true, maxKeys, blockGasLimit);
    }

    function test_SetModuleConfig_RevertWhen_WrongModuleId() public {
        vm.prank(committee);
        vm.expectRevert(IStakingRouter.StakingModuleUnregistered.selector);
        ccr.setModuleConfig(999, true, maxKeys, blockGasLimit);
    }

    function test_ModuleConfig_OverrideBlockGasLimit() public {
        // module config not yet set
        assertEq(ccr.getModuleBlockGasLimit(moduleId), defaultBlockGasLimit);

        vm.prank(committee);
        ccr.setModuleConfig(moduleId, false, 0, blockGasLimit);
        assertEq(ccr.getModuleBlockGasLimit(moduleId), blockGasLimit);

        // set block gas limit to 0
        vm.prank(committee);
        ccr.setModuleConfig(moduleId, false, 0, 0);
        assertEq(ccr.getModuleBlockGasLimit(moduleId), defaultBlockGasLimit);
    }

    function test_ModuleConfig_ZeroBlockGasLimitWhenModuleDisabled() public {
        // module config not yet set
        assertEq(ccr.getModuleBlockGasLimit(moduleId), defaultBlockGasLimit);

        // disable module
        vm.prank(committee);
        ccr.setModuleConfig(moduleId, true, 0, 0);
        assertEq(ccr.getModuleBlockGasLimit(moduleId), 0);

        // enable module
        vm.prank(committee);
        ccr.setModuleConfig(moduleId, false, 0, 0);
        assertEq(ccr.getModuleBlockGasLimit(moduleId), defaultBlockGasLimit);
    }

    function test_ModuleConfig_OverrideOperatorMaxKeys() public {
        // module config not yet set
        assertEq(ccr.getModuleOperatorMaxKeys(moduleId), defaultOperatorMaxKeys);

        vm.prank(committee);
        ccr.setModuleConfig(moduleId, false, maxKeys, 0);
        assertEq(ccr.getModuleOperatorMaxKeys(moduleId), maxKeys);

        // set block gas limit to 0
        vm.prank(committee);
        ccr.setModuleConfig(moduleId, false, 0, 0);
        assertEq(ccr.getModuleOperatorMaxKeys(moduleId), defaultOperatorMaxKeys);
    }

    function test_ModuleConfig_ZeroOperatorMaxKeysWhenModuleDisabled() public {
        // module config not yet set
        assertEq(ccr.getModuleOperatorMaxKeys(moduleId), defaultOperatorMaxKeys);

        // disable module
        vm.prank(committee);
        ccr.setModuleConfig(moduleId, true, 0, 0);
        assertEq(ccr.getModuleOperatorMaxKeys(moduleId), 0);

        // enable module
        vm.prank(committee);
        ccr.setModuleConfig(moduleId, false, 0, 0);
        assertEq(ccr.getModuleOperatorMaxKeys(moduleId), defaultOperatorMaxKeys);
    }
}
