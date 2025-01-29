// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {CCCP} from "../src/CCCP.sol";
import {CCCPMock} from "./helpers/mocks/CCCPMock.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {CCCPCommon} from "./helpers/CCCPCommon.sol";

contract CCCPInitialize is CCCPCommon {
    function test_constructor() public {
        CCCPMock cccp = new CCCPMock({lidoLocator: address(locator), csModuleType: "csm-type"});
        assertEq(cccp.__test__getCSModuleType(), "csm-type");
        assertEq(address(cccp.LIDO_LOCATOR()), address(locator));
        assertEq(cccp.getContractVersion(), type(uint64).max);
    }

    function test_constructor_RevertWhen_ZeroLocator() public {
        vm.expectRevert(CCCP.ZeroLocatorAddress.selector);
        new CCCP({lidoLocator: address(0), csModuleType: "csm-type"});
    }

    function test_constructor_RevertWhen_InitOnImpl() public {
        CCCP cccp = new CCCP({lidoLocator: address(locator), csModuleType: "csm-type"});

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        cccp.initialize({
            committeeAddress: committee,
            optInMinDurationBlocks: 0,
            optOutDelayDurationBlocks: 0,
            defaultOperatorMaxValidators: 10,
            defaultBlockGasLimit: 1000000
        });
    }

    function test_initialize() public {
        CCCP cccp = new CCCP({lidoLocator: address(locator), csModuleType: "csm-type"});
        _enableInitializers(address(cccp));
        cccp.initialize({
            committeeAddress: committee,
            optInMinDurationBlocks: 32,
            optOutDelayDurationBlocks: 64,
            defaultOperatorMaxValidators: 10,
            defaultBlockGasLimit: 1000000
        });

        (
            uint64 optInMinDurationBlocks,
            uint64 optOutDelayDurationBlocks,
            uint64 defaultOperatorMaxValidators,
            uint64 defaultBlockGasLimit
        ) = cccp.getConfig();

        assertEq(optInMinDurationBlocks, 32);
        assertEq(optOutDelayDurationBlocks, 64);
        assertEq(defaultOperatorMaxValidators, 10);
        assertEq(defaultBlockGasLimit, 1000000);
        assertEq(cccp.getContractVersion(), 1);
        assertFalse(cccp.paused());
    }
}
