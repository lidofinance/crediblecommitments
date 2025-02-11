// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {CCR} from "../src/CCR.sol";
import {CCRMock} from "./helpers/mocks/CCRMock.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {CCRCommon} from "./helpers/CCRCommon.sol";

contract CCRInitialize is CCRCommon {
    function test_constructor() public {
        CCRMock ccr = new CCRMock({lidoLocator: address(locator), csModuleType: "csm-type"});
        assertEq(ccr.__test__getCSModuleType(), "csm-type");
        assertEq(address(ccr.LIDO_LOCATOR()), address(locator));
        assertEq(ccr.getContractVersion(), type(uint64).max);
    }

    function test_constructor_RevertWhen_ZeroLocator() public {
        vm.expectRevert(CCR.ZeroLocatorAddress.selector);
        new CCR({lidoLocator: address(0), csModuleType: "csm-type"});
    }

    function test_constructor_RevertWhen_InitOnImpl() public {
        CCR ccr = new CCR({lidoLocator: address(locator), csModuleType: "csm-type"});

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        ccr.initialize({
            committeeAddress: committee,
            optInDelayBlocks: 0,
            optOutDelayBlocks: 0,
            defaultOperatorMaxKeys: 10,
            defaultBlockGasLimit: 1000000
        });
    }

    function test_initialize() public {
        CCR ccr = new CCR({lidoLocator: address(locator), csModuleType: "csm-type"});
        _enableInitializers(address(ccr));
        ccr.initialize({
            committeeAddress: committee,
            optInDelayBlocks: 32,
            optOutDelayBlocks: 64,
            defaultOperatorMaxKeys: 10,
            defaultBlockGasLimit: 1000000
        });

        (uint64 optInDelayBlocks, uint64 optOutDelayBlocks, uint64 defaultOperatorMaxKeys, uint64 defaultBlockGasLimit)
        = ccr.getConfig();

        assertEq(optInDelayBlocks, 32);
        assertEq(optOutDelayBlocks, 64);
        assertEq(defaultOperatorMaxKeys, 10);
        assertEq(defaultBlockGasLimit, 1000000);
        assertEq(ccr.getContractVersion(), 1);
        assertFalse(ccr.paused());
    }
}
