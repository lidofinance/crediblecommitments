// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {CCCPCommon} from "./helpers/CCCPCommon.sol";

import {CCCP} from "../src/CCCP.sol";
import {CCCPMock} from "./helpers/mocks/CCCPMock.sol";
import {IStakingRouter} from "test/helpers/mocks/StakingRouterMock.sol";
import {ICCCPOperatorStatesStorage} from "../src/interfaces/ICCCPOperatorStatesStorage.sol";

contract CCCPOptIn is CCCPCommon {
    CCCP public cccp;

    uint64 public noCsm1Id;
    uint64 public noCurated1Id;

    uint24 public constant norId = 1;
    uint24 public constant csmId = 2;

    string public constant rpcUrl1 = "some-url-1";
    string public constant rpcUrl2 = "some-url-2";

    function setUp() public virtual override {
        super.setUp();

        noCsm1 = nextAddress("NO_CSM1");
        noCurated1 = nextAddress("NO_CURATED1");
        noCsm1Manager = nextAddress("NO_CSM1_MANAGER");
        noCurated1Manager = nextAddress("NO_CURATED1_MANAGER");

        cccp = new CCCPMock(address(locator), "community-onchain-v1");
        _enableInitializers(address(cccp));
        cccp.initialize({
            committeeAddress: committee,
            optInMinDurationBlocks: 0,
            optOutDelayDurationBlocks: 0,
            defaultOperatorMaxValidators: 10,
            defaultBlockGasLimit: 1000000
        });

        noCsm1Id = createNo(csm, noCsm1, 10);
        noCurated1Id = createNo(nor, noCurated1, 10);
    }

    function test_OptIn() public {
        // opt in on behalf of noCsm1
        vm.broadcast(noCsm1);
        vm.expectEmit(true, true, true, false, address(cccp));
        emit CCCP.OperatorManagerUpdated(csmId, noCsm1Id, noCsm1Manager);
        vm.expectEmit(true, true, true, false, address(cccp));
        emit CCCP.KeysRangeUpdated(csmId, noCsm1Id, 2, 4);
        vm.expectEmit(true, true, true, false, address(cccp));
        emit CCCP.RPCUrlUpdated(csmId, noCsm1Id, rpcUrl1);
        vm.expectEmit(true, true, true, false, address(cccp));
        emit CCCP.OptInSucceeded(csmId, noCsm1Id, noCsm1Manager);

        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            keyIndexStart: 2,
            keyIndexEnd: 4,
            rpcURL: rpcUrl1
        });

        assertEq(cccp.getOperatorIsEnabledForPreconf(csmId, noCsm1Id), true);
        assertEq(cccp.getOperatorManager(csmId, noCsm1Id), noCsm1Manager);
    }

    function test_GetOperatorByManager() public {
        // opt in on behalf of noCsm1
        vm.broadcast(noCsm1);
        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            keyIndexStart: 2,
            keyIndexEnd: 4,
            rpcURL: rpcUrl1
        });

        (uint24 moduleId, uint64 operatorId, bool isEnabled, CCCP.OperatorState memory state) =
            cccp.getOperator(noCsm1Manager);

        assertEq(moduleId, csmId);
        assertEq(operatorId, noCsm1Id);
        assertEq(isEnabled, true);

        assertEq(state.keysRange.indexStart, 2);
        assertEq(state.keysRange.indexEnd, 4);
        assertEq(state.manager, noCsm1Manager);
        assertEq(state.optInOutState.optInBlock, block.number);
        assertEq(state.optInOutState.optOutBlock, 0);
        assertEq(state.optInOutState.isOptOutForced, false);
        assertEq(state.extraData.rpcURL, rpcUrl1);
    }

    function test_GetOperatorById() public {
        // opt in on behalf of noCsm1
        vm.broadcast(noCsm1);
        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            keyIndexStart: 2,
            keyIndexEnd: 4,
            rpcURL: rpcUrl1
        });

        (uint24 moduleId, uint64 operatorId, bool isEnabled, CCCP.OperatorState memory state) =
            cccp.getOperator(csmId, noCsm1Id);

        assertEq(moduleId, csmId);
        assertEq(operatorId, noCsm1Id);
        assertEq(isEnabled, true);

        assertEq(state.keysRange.indexStart, 2);
        assertEq(state.keysRange.indexEnd, 4);
        assertEq(state.manager, noCsm1Manager);
        assertEq(state.optInOutState.optInBlock, block.number);
        assertEq(state.optInOutState.optOutBlock, 0);
        assertEq(state.optInOutState.isOptOutForced, false);
        assertEq(state.extraData.rpcURL, rpcUrl1);
    }

    function test_OptIn_RevertWhen_ZeroManagerAddress() public {
        vm.expectRevert(CCCP.ZeroOperatorManagerAddress.selector);
        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: address(0),
            keyIndexStart: 2,
            keyIndexEnd: 4,
            rpcURL: ""
        });
    }

    function test_OptIn_RevertWhen_WrongRewardAddress() public {
        vm.broadcast(stranger1);
        vm.expectRevert(CCCP.RewardAddressMismatch.selector);
        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            keyIndexStart: 2,
            keyIndexEnd: 4,
            rpcURL: ""
        });
    }

    function test_OptIn_RevertWhen_WrongModuleId() public {
        vm.broadcast(noCsm1);
        vm.expectRevert(IStakingRouter.StakingModuleUnregistered.selector);
        cccp.optIn({
            moduleId: 999,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            keyIndexStart: 2,
            keyIndexEnd: 4,
            rpcURL: ""
        });
    }

    function test_OptIn_RevertWhen_LidoOperatorNotActive() public {
        // set noCsm1 to inactive
        updateNoActive(csm, noCsm1Id, false);

        vm.broadcast(noCsm1);
        vm.expectRevert(CCCP.OperatorNotActive.selector);
        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            keyIndexStart: 2,
            keyIndexEnd: 4,
            rpcURL: ""
        });
    }

    function test_OptIn_RevertWhen_OperatorAlreadyOptedIn() public {
        // optin
        vm.broadcast(noCsm1);
        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            keyIndexStart: 2,
            keyIndexEnd: 4,
            rpcURL: ""
        });

        // repeat optin
        vm.broadcast(noCsm1);
        vm.expectRevert(CCCP.OperatorAlreadyRegistered.selector);
        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            keyIndexStart: 2,
            keyIndexEnd: 4,
            rpcURL: ""
        });
    }

    function test_OptIn_RevertWhen_OperatorForceOptedOut() public {
        // optin
        vm.broadcast(noCsm1);
        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            keyIndexStart: 2,
            keyIndexEnd: 4,
            rpcURL: ""
        });

        // force optout
        vm.roll(block.number + 100);
        vm.broadcast(committee);
        cccp.optOut({moduleId: csmId, operatorId: noCsm1Id});

        // repeat optin
        vm.roll(block.number + 100);
        vm.broadcast(noCsm1);
        vm.expectRevert(CCCP.OperatorOptInNotAllowed.selector);
        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            keyIndexStart: 2,
            keyIndexEnd: 4,
            rpcURL: ""
        });
    }

    function test_OptIn_RevertWhen_ManagerBelongsOtherOperator() public {
        // optin
        vm.broadcast(noCurated1);
        cccp.optIn({
            moduleId: norId,
            operatorId: noCurated1Id,
            manager: noCurated1Manager,
            keyIndexStart: 2,
            keyIndexEnd: 4,
            rpcURL: ""
        });

        // optin with same manager
        vm.broadcast(noCsm1);
        vm.expectRevert(ICCCPOperatorStatesStorage.ManagerBelongsToOtherOperator.selector);
        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCurated1Manager,
            keyIndexStart: 2,
            keyIndexEnd: 4,
            rpcURL: ""
        });
    }

    function test_OptIn_RevertWhen_KeyIndexWrongOrder() public {
        // optin
        vm.broadcast(noCsm1);
        vm.expectRevert(CCCP.KeyIndexMismatch.selector);
        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            keyIndexStart: 4,
            keyIndexEnd: 2,
            rpcURL: ""
        });
    }

    function test_OptIn_RevertWhen_KeyIndexOutOfRange() public {
        // optin
        vm.broadcast(noCsm1);
        vm.expectRevert(CCCP.KeyIndexOutOfRange.selector);
        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            keyIndexStart: 2,
            keyIndexEnd: 100,
            rpcURL: ""
        });
    }
}
