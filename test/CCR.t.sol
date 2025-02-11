// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {CCRCommon} from "./helpers/CCRCommon.sol";

import {CCR} from "../src/CCR.sol";
import {CCRMock} from "./helpers/mocks/CCRMock.sol";
import {IStakingRouter} from "test/helpers/mocks/StakingRouterMock.sol";
import {ICCROperatorStatesStorage} from "../src/interfaces/ICCROperatorStatesStorage.sol";

contract CCROptIn is CCRCommon {
    CCR public ccr;

    uint64 public noCsm1Id;
    uint64 public noCurated1Id;

    uint24 public constant norId = 1;
    uint24 public constant csmId = 2;

    string public constant rpcUrl1 = "some-url-1";
    string public constant rpcUrl2 = "some-url-2";

    uint32 public constant opKeysCount = 10;

    uint64 public constant optInDelayBlocks = 0;
    uint64 public constant optOutDelayBlocks = 0;
    uint64 public constant defaultOperatorMaxKeys = 100;
    uint64 public constant defaultBlockGasLimit = 1000000;

    function setUp() public virtual override {
        super.setUp();

        noCsm1 = nextAddress("NO_CSM1");
        noCurated1 = nextAddress("NO_CURATED1");
        noCsm1Manager = nextAddress("NO_CSM1_MANAGER");
        noCurated1Manager = nextAddress("NO_CURATED1_MANAGER");

        ccr = new CCRMock(address(locator), "community-onchain-v1");
        _enableInitializers(address(ccr));
        ccr.initialize({
            committeeAddress: committee,
            optInDelayBlocks: optInDelayBlocks,
            optOutDelayBlocks: optOutDelayBlocks,
            defaultOperatorMaxKeys: defaultOperatorMaxKeys,
            defaultBlockGasLimit: defaultBlockGasLimit
        });

        noCsm1Id = createNo(csm, noCsm1, opKeysCount);
        noCurated1Id = createNo(nor, noCurated1, opKeysCount);
    }

    function test_OptIn() public {
        // opt in on behalf of noCsm1
        vm.prank(noCsm1);
        vm.expectEmit(true, true, true, false, address(ccr));
        emit CCR.OperatorManagerUpdated(csmId, noCsm1Id, noCsm1Manager);
        vm.expectEmit(true, true, true, false, address(ccr));
        emit CCR.OperatorCommitmentAdded(csmId, noCsm1Id, 2, 4, rpcUrl1);
        vm.expectEmit(true, true, true, false, address(ccr));
        emit CCR.OptInSucceeded(csmId, noCsm1Id);

        ccr.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            indexStart: 2,
            indexEnd: 4,
            rpcURL: rpcUrl1
        });

        assertEq(ccr.getOperatorIsEnabledForPreconf(csmId, noCsm1Id), true);
        assertEq(ccr.getOperatorManager(csmId, noCsm1Id), noCsm1Manager);
    }

    function test_GetOperator() public {
        // opt in on behalf of noCsm1
        vm.prank(noCsm1);
        ccr.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            indexStart: 2,
            indexEnd: 4,
            rpcURL: rpcUrl1
        });

        (address manager, bool isBlocked, bool isEnabled, CCR.OptInOutState memory optInOutState) =
            ccr.getOperator(csmId, noCsm1Id);

        assertEq(manager, noCsm1Manager);
        assertEq(isBlocked, false);
        assertEq(isEnabled, true);
        assertEq(optInOutState.optInBlock, block.number);
        assertEq(optInOutState.optOutBlock, 0);

        CCR.Commitment[] memory commitments = ccr.getOperatorCommitments(csmId, noCsm1Id);

        assertEq(commitments.length, 1);
        assertEq(commitments[0].keyRange.indexStart, 2);
        assertEq(commitments[0].keyRange.indexEnd, 4);
        assertEq(commitments[0].extraData.rpcURL, rpcUrl1);
    }

    function test_OptIn_RevertWhen_ZeroManagerAddress() public {
        vm.expectRevert(CCR.ZeroOperatorManagerAddress.selector);
        ccr.optIn({moduleId: csmId, operatorId: noCsm1Id, manager: address(0), indexStart: 2, indexEnd: 4, rpcURL: ""});
    }

    function test_OptIn_RevertWhen_WrongRewardAddress() public {
        vm.prank(stranger1);
        vm.expectRevert(CCR.RewardAddressMismatch.selector);
        ccr.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            indexStart: 2,
            indexEnd: 4,
            rpcURL: ""
        });
    }

    function test_OptIn_RevertWhen_WrongModuleId() public {
        vm.prank(noCsm1);
        vm.expectRevert(IStakingRouter.StakingModuleUnregistered.selector);
        ccr.optIn({moduleId: 999, operatorId: noCsm1Id, manager: noCsm1Manager, indexStart: 2, indexEnd: 4, rpcURL: ""});
    }

    function test_OptIn_RevertWhen_LidoOperatorNotActive() public {
        // set noCsm1 to inactive
        updateNoActive(csm, noCsm1Id, false);

        vm.prank(noCsm1);
        vm.expectRevert(CCR.OperatorNotActive.selector);
        ccr.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            indexStart: 2,
            indexEnd: 4,
            rpcURL: ""
        });
    }

    function test_OptIn_RevertWhen_OperatorAlreadyOptedIn() public {
        // optin
        vm.prank(noCsm1);
        ccr.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            indexStart: 2,
            indexEnd: 4,
            rpcURL: ""
        });

        // repeat optin
        vm.prank(noCsm1);
        vm.expectRevert(CCR.OperatorOptedIn.selector);
        ccr.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            indexStart: 2,
            indexEnd: 4,
            rpcURL: ""
        });
    }

    function test_OptIn_RevertWhen_OperatorForceOptedOut() public {
        // optin
        vm.prank(noCsm1);
        ccr.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            indexStart: 2,
            indexEnd: 4,
            rpcURL: ""
        });

        // force optout
        vm.roll(block.number + 100);
        vm.prank(committee);
        ccr.optOut({moduleId: csmId, operatorId: noCsm1Id});

        // repeat optin
        vm.roll(block.number + 100);
        vm.prank(noCsm1);
        vm.expectRevert(CCR.OperatorBlocked.selector);
        ccr.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            indexStart: 2,
            indexEnd: 4,
            rpcURL: ""
        });
    }

    function test_OptIn_RevertWhen_ManagerBelongsOtherOperator() public {
        // optin
        vm.prank(noCurated1);
        ccr.optIn({
            moduleId: norId,
            operatorId: noCurated1Id,
            manager: noCurated1Manager,
            indexStart: 2,
            indexEnd: 4,
            rpcURL: ""
        });

        // optin with same manager
        vm.prank(noCsm1);
        vm.expectRevert(ICCROperatorStatesStorage.ManagerBelongsToOtherOperator.selector);
        ccr.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCurated1Manager,
            indexStart: 2,
            indexEnd: 4,
            rpcURL: ""
        });
    }

    function test_OptIn_RevertWhen_KeyIndexWrongOrder() public {
        // optin
        vm.prank(noCsm1);
        vm.expectRevert(CCR.KeyIndexMismatch.selector);
        ccr.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            indexStart: 4,
            indexEnd: 2,
            rpcURL: ""
        });
    }

    function test_OptIn_RevertWhen_KeyIndexOutOfRange() public {
        // optin
        vm.prank(noCsm1);
        vm.expectRevert(CCR.KeyIndexOutOfRange.selector);
        ccr.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            indexStart: 2,
            indexEnd: 100,
            rpcURL: ""
        });
    }

    function test_getOperatorIsEnabledForPreconf() public {
        // wrong op id
        // assertFalse(ccr.getOperatorIsEnabledForPreconf(csmId, 999));

        // not yet opted in
        assertFalse(ccr.getOperatorIsEnabledForPreconf(csmId, noCsm1Id));
        // opt in on behalf of noCsm1
        vm.prank(noCsm1);
        ccr.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            indexStart: 2,
            indexEnd: 4,
            rpcURL: rpcUrl1
        });
        // opted in
        assertTrue(ccr.getOperatorIsEnabledForPreconf(csmId, noCsm1Id));
    }

    function test_GetOperatorAllowedKeys() public {
        vm.prank(committee);
        ccr.setModuleConfig(csmId, true, 0, 0);
        // 0 for disabled module
        assertEq(ccr.getOperatorAllowedKeys(csmId, noCsm1Id), 0);

        vm.prank(committee);
        ccr.setModuleConfig(csmId, false, 0, 0);

        // set noCsm1 to inactive
        updateNoActive(csm, noCsm1Id, false);
        // 0 for inactive operator
        assertEq(ccr.getOperatorAllowedKeys(csmId, noCsm1Id), 0);
        updateNoActive(csm, noCsm1Id, true);

        /// operator NOT yet opted in
        ///
        vm.prank(committee);
        ccr.setConfig(0, 0, opKeysCount - 1, defaultBlockGasLimit);

        // operatorMaxKeys when operatorMaxKeys < operatorTotalAddedKeys
        assertEq(ccr.getOperatorAllowedKeys(csmId, noCsm1Id), opKeysCount - 1);

        vm.prank(committee);
        ccr.setConfig(0, 99, defaultOperatorMaxKeys, defaultBlockGasLimit);

        // operatorTotalAddedKeys when operatorMaxKeys > operatorTotalAddedKeys
        assertEq(ccr.getOperatorAllowedKeys(csmId, noCsm1Id), opKeysCount);

        // opt in on behalf of noCsm1 with 3 keys
        vm.prank(noCsm1);
        ccr.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            indexStart: 2,
            indexEnd: 4,
            rpcURL: rpcUrl1
        });

        // operatorMaxKeys > operatorTotalAddedKeys
        assertEq(ccr.getOperatorAllowedKeys(csmId, noCsm1Id), opKeysCount - 3);

        // voluntary opt out
        vm.roll(block.number + 100);
        vm.prank(noCsm1Manager);
        ccr.optOut();

        vm.roll(block.number + 100);
        assertEq(ccr.getOperatorAllowedKeys(csmId, noCsm1Id), opKeysCount);

        // opt in on behalf of noCsm1 with 9 keys
        vm.prank(noCsm1);
        ccr.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            indexStart: 0,
            indexEnd: 8,
            rpcURL: rpcUrl1
        });
        assertEq(ccr.getOperatorAllowedKeys(csmId, noCsm1Id), opKeysCount - 9);

        // reduce max operator keys in module config to 5
        vm.prank(committee);
        ccr.setModuleConfig(csmId, false, 5, 0);
        // operator opted in totalKeys > operatorMaxKeys
        assertEq(ccr.getOperatorAllowedKeys(csmId, noCsm1Id), 0);

        // force optout
        vm.roll(block.number + 100);
        vm.prank(committee);
        ccr.optOut({moduleId: csmId, operatorId: noCsm1Id});

        // optOut finished, but forced optout
        vm.roll(block.number + 100);
        assertEq(ccr.getOperatorAllowedKeys(csmId, noCsm1Id), 0);
    }
}
