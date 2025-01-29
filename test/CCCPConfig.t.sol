// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {CCCPCommon} from "./helpers/CCCPCommon.sol";

import {CCCP} from "../src/CCCP.sol";
import {IStakingRouter} from "test/helpers/mocks/StakingRouterMock.sol";
import {ICCCPConfigStorage} from "../src/interfaces/ICCCPConfigStorage.sol";

contract CCCPConfig is CCCPCommon {
    CCCP public cccp;
    uint24 public moduleId = 1;
    uint64 public maxValidators = 1111;
    uint64 public blockGasLimit = 1111111;

    uint64 optInMinDurationBlocks = 32;
    uint64 optOutDelayDurationBlocks = 64;
    uint64 defaultOperatorMaxValidators = 100;
    uint64 defaultBlockGasLimit = 1000000;

    function setUp() public virtual override {
        super.setUp();

        cccp = new CCCP(address(locator), "community-onchain-v1");
        _enableInitializers(address(cccp));
        cccp.initialize({
            committeeAddress: committee,
            optInMinDurationBlocks: optInMinDurationBlocks,
            optOutDelayDurationBlocks: optOutDelayDurationBlocks,
            defaultOperatorMaxValidators: defaultOperatorMaxValidators,
            defaultBlockGasLimit: defaultBlockGasLimit
        });
    }

    function test_GetInitialConfig() public view {
        (
            uint64 newOptInMinDurationBlocks,
            uint64 newOptOutDelayDurationBlocks,
            uint64 newDefaultOperatorMaxValidators,
            uint64 newDefaultBlockGasLimit
        ) = cccp.getConfig();

        assertEq(newOptInMinDurationBlocks, optInMinDurationBlocks);
        assertEq(newOptOutDelayDurationBlocks, optOutDelayDurationBlocks);
        assertEq(newDefaultOperatorMaxValidators, defaultOperatorMaxValidators);
        assertEq(newDefaultBlockGasLimit, defaultBlockGasLimit);
    }

    function test_SetConfig() public {
        vm.prank(committee);
        cccp.setConfig(10, 20, 30, 40);
        (
            uint64 newOptInMinDurationBlocks,
            uint64 newOptOutDelayDurationBlocks,
            uint64 newDefaultOperatorMaxValidators,
            uint64 newDefaultBlockGasLimit
        ) = cccp.getConfig();

        assertEq(newOptInMinDurationBlocks, 10);
        assertEq(newOptOutDelayDurationBlocks, 20);
        assertEq(newDefaultOperatorMaxValidators, 30);
        assertEq(newDefaultBlockGasLimit, 40);
    }

    function test_SetConfig_RevertWhen_CallerNotCommittee() public {
        bytes32 role = cccp.COMMITTEE_ROLE();

        vm.prank(stranger1);
        expectRoleRevert(stranger1, role);
        cccp.setConfig(
            optInMinDurationBlocks, optOutDelayDurationBlocks, defaultOperatorMaxValidators, defaultBlockGasLimit
        );
    }

    function test_SetConfig_RevertWhen_ZeroDefaultOperatorMaxValidators() public {
        vm.prank(committee);
        vm.expectRevert(ICCCPConfigStorage.ZeroDefaultOperatorMaxValidators.selector);
        cccp.setConfig(optInMinDurationBlocks, optOutDelayDurationBlocks, 0, defaultBlockGasLimit);
    }

    function test_SetConfig_RevertWhen_ZeroDefaultBlockGasLimit() public {
        vm.prank(committee);
        vm.expectRevert(ICCCPConfigStorage.ZeroDefaultBlockGasLimit.selector);
        cccp.setConfig(optInMinDurationBlocks, optOutDelayDurationBlocks, defaultOperatorMaxValidators, 0);
    }

    function test_SetModuleConfig() public {
        vm.prank(committee);
        cccp.setModuleConfig(moduleId, true, maxValidators, blockGasLimit);
        (bool newIsDisabled, uint64 newMaxValidators, uint64 newblockGasLimit) = cccp.getModuleConfig(moduleId);

        assertEq(newIsDisabled, true);
        assertEq(newMaxValidators, maxValidators);
        assertEq(newblockGasLimit, blockGasLimit);
    }

    function test_SetModuleConfig_RevertWhen_CallerNotCommittee() public {
        bytes32 role = cccp.COMMITTEE_ROLE();

        vm.prank(stranger1);
        expectRoleRevert(stranger1, role);
        cccp.setModuleConfig(moduleId, true, maxValidators, blockGasLimit);
    }

    function test_SetModuleConfig_RevertWhen_WrongModuleId() public {
        vm.prank(committee);
        vm.expectRevert(IStakingRouter.StakingModuleUnregistered.selector);
        cccp.setModuleConfig(999, true, maxValidators, blockGasLimit);
    }

    function test_ModuleConfig_OverrideBlockGasLimit() public {
        // module config not yet set
        assertEq(cccp.getModuleBlockGasLimit(moduleId), defaultBlockGasLimit);

        vm.prank(committee);
        cccp.setModuleConfig(moduleId, false, 0, blockGasLimit);
        assertEq(cccp.getModuleBlockGasLimit(moduleId), blockGasLimit);

        // set block gas limit to 0
        vm.prank(committee);
        cccp.setModuleConfig(moduleId, false, 0, 0);
        assertEq(cccp.getModuleBlockGasLimit(moduleId), defaultBlockGasLimit);
    }

    function test_ModuleConfig_ZeroBlockGasLimitWhenModuleDisabled() public {
        // module config not yet set
        assertEq(cccp.getModuleBlockGasLimit(moduleId), defaultBlockGasLimit);

        // disable module
        vm.prank(committee);
        cccp.setModuleConfig(moduleId, true, 0, 0);
        assertEq(cccp.getModuleBlockGasLimit(moduleId), 0);

        // enable module
        vm.prank(committee);
        cccp.setModuleConfig(moduleId, false, 0, 0);
        assertEq(cccp.getModuleBlockGasLimit(moduleId), defaultBlockGasLimit);
    }

    function test_ModuleConfig_OverrideOperatorMaxValidators() public {
        // module config not yet set
        assertEq(cccp.getModuleOperatorMaxValidators(moduleId), defaultOperatorMaxValidators);

        vm.prank(committee);
        cccp.setModuleConfig(moduleId, false, maxValidators, 0);
        assertEq(cccp.getModuleOperatorMaxValidators(moduleId), maxValidators);

        // set block gas limit to 0
        vm.prank(committee);
        cccp.setModuleConfig(moduleId, false, 0, 0);
        assertEq(cccp.getModuleOperatorMaxValidators(moduleId), defaultOperatorMaxValidators);
    }

    function test_ModuleConfig_ZeroOperatorMaxValidatorsWhenModuleDisabled() public {
        // module config not yet set
        assertEq(cccp.getModuleOperatorMaxValidators(moduleId), defaultOperatorMaxValidators);

        // disable module
        vm.prank(committee);
        cccp.setModuleConfig(moduleId, true, 0, 0);
        assertEq(cccp.getModuleOperatorMaxValidators(moduleId), 0);

        // enable module
        vm.prank(committee);
        cccp.setModuleConfig(moduleId, false, 0, 0);
        assertEq(cccp.getModuleOperatorMaxValidators(moduleId), defaultOperatorMaxValidators);
    }

    // function test_GetInitialConfig() public {
    //     (
    //         uint64 newOptInMinDurationBlocks,
    //         uint64 newOptOutDelayDurationBlocks,
    //         uint64 newDefaultOperatorMaxValidators,
    //         uint64 newDefaultBlockGasLimit
    //     ) = cccp.getConfig();

    //     assertEq(newOptInMinDurationBlocks, 32);
    //     assertEq(newOptOutDelayDurationBlocks, 64);
    //     assertEq(newDefaultOperatorMaxValidators, 100);
    //     assertEq(newDefaultBlockGasLimit, 1000000);
    // }
}
