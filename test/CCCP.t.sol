// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {CCCPDataStorage as DS, ModuleState, Config} from "../src/lib/CCCPDataStorage.sol";
import {
    CredibleCommitmentCurationProvider as CCCP, OperatorState
} from "../src/CredibleCommitmentCurationProvider.sol";
import {CCCPMock} from "./helpers/mocks/CCCPMock.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./helpers/Fixtures.sol";
import "./helpers/Utilities.sol";
import {LidoLocatorMock} from "test/helpers/mocks/LidoLocatorMock.sol";
import {StakingModuleMock} from "test/helpers/mocks/StakingModuleMock.sol";
import {StakingRouterMock} from "test/helpers/mocks/StakingRouterMock.sol";
import {CuratedModuleMock} from "test/helpers/mocks/CuratedModuleMock.sol";
import {CSModuleMock} from "test/helpers/mocks/CSModuleMock.sol";

abstract contract CCCPFixtures is Test, Fixtures, Utilities {
    LidoLocatorMock public locator;
    StakingRouterMock public sr;
    CuratedModuleMock public nor;
    CSModuleMock public csm;

    // address internal admin;
    address internal stranger1;
    address internal stranger2;
    address internal noCsm1;
    address internal noCsm1Manager;
    address internal noCurated1;
    address internal noCurated1Manager;
    address internal committee;

    // uint64 optInMinDurationBlocks = 100;
    // uint64 optOutDelayDurationBlocks = 200;
    // uint64 defaultOperatorMaxValidators = 100;
    // uint64 defaultBlockGasLimit = 1000000;

    // function createNo(uint256 modId, address rewAddr) internal returns (uint256) {
    //     StakingModuleMock m = StakingModuleMock(sr.getStakingModule(modId).stakingModuleAddress);
    //     return createNo(csm, rewAddr, 1);
    // }

    function createNo(StakingModuleMock m, address rewAddr, uint32 keysCount) internal returns (uint64) {
        m.addNo(true, rewAddr, keysCount);
        return uint64(m.getNodeOperatorsCount() - 1);
    }

    function updateNoKeys(StakingModuleMock m, uint256 noId, uint32 keysCount) internal {
        m.updNoKeys(noId, keysCount);
    }

    function updateNoActive(StakingModuleMock m, uint256 noId, bool active) internal {
        m.updNoActive(noId, active);
    }
}

contract CCCPCommon is CCCPFixtures {
    function setUp() public virtual {
        committee = nextAddress("COMMITTEE");
        stranger1 = nextAddress("STRANGER1");
        stranger2 = nextAddress("STRANGER2");

        (locator, sr, nor, csm) = initLidoMock();
    }
}

contract CCCPInitialize is CCCPCommon {
    function test_constructor() public {
        CCCPMock cccp = new CCCPMock({lidoLocator: address(locator), csModuleType: "csm-type"});
        assertEq(cccp.__test__getCSModuleType(), "csm-type");
        assertEq(address(cccp.LIDO_LOCATOR()), address(locator));
        assertEq(cccp.getContractVersion(), type(uint64).max);
    }

    function test_constructor_RevertWhen_ZeroLocator() public {
        vm.expectRevert(CCCP.ZeroLocatorAddress.selector);
        new CCCPMock({lidoLocator: address(0), csModuleType: "csm-type"});
    }

    function test_constructor_RevertWhen_InitOnImpl() public {
        CCCPMock cccp = new CCCPMock({lidoLocator: address(locator), csModuleType: "csm-type"});

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
        CCCPMock cccp = new CCCPMock({lidoLocator: address(locator), csModuleType: "csm-type"});
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

contract CCCPOptIn is CCCPCommon {
    CCCPMock public cccp;

    uint64 public noCsm1Id;
    uint64 public noCurated1Id;

    uint24 public constant norId = 1;
    uint24 public constant csmId = 2;

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
        emit CCCP.KeyRangeUpdated(csmId, noCsm1Id, 2, 4);
        vm.expectEmit(true, true, true, false, address(cccp));
        emit CCCP.OptInSucceeded(csmId, noCsm1Id, noCsm1Manager);

        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            newKeyIndexRangeStart: 2,
            newKeyIndexRangeEnd: 4,
            rpcURL: ""
        });

        (uint24 moduleId, uint64 operatorId, bool isEnabled, OperatorState memory state) =
            cccp.getOperator(noCsm1Manager);

        assertEq(moduleId, csmId);
        assertEq(operatorId, noCsm1Id);
        assertEq(isEnabled, true);

        assertEq(state.keysRangeState.indexStart, 2);
        assertEq(state.keysRangeState.indexEnd, 4);
        assertEq(state.manager, noCsm1Manager);
        assertEq(state.optInOutState.optInBlock, block.number);
        assertEq(state.optInOutState.optOutBlock, 0);
        assertEq(state.optInOutState.isOptOutForced, false);
        assertEq(state.extraData.rpcURL, "");
    }

    function test_OptIn_RevertWhen_ZeroManagerAddress() public {
        vm.expectRevert(CCCP.ZeroOperatorManagerAddress.selector);
        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: address(0),
            newKeyIndexRangeStart: 2,
            newKeyIndexRangeEnd: 4,
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
            newKeyIndexRangeStart: 2,
            newKeyIndexRangeEnd: 4,
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
            newKeyIndexRangeStart: 2,
            newKeyIndexRangeEnd: 4,
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
            newKeyIndexRangeStart: 2,
            newKeyIndexRangeEnd: 4,
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
            newKeyIndexRangeStart: 2,
            newKeyIndexRangeEnd: 4,
            rpcURL: ""
        });

        // repeat optin
        vm.broadcast(noCsm1);
        vm.expectRevert(CCCP.OperatorAlreadyRegistered.selector);
        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCsm1Manager,
            newKeyIndexRangeStart: 2,
            newKeyIndexRangeEnd: 4,
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
            newKeyIndexRangeStart: 2,
            newKeyIndexRangeEnd: 4,
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
            newKeyIndexRangeStart: 2,
            newKeyIndexRangeEnd: 4,
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
            newKeyIndexRangeStart: 2,
            newKeyIndexRangeEnd: 4,
            rpcURL: ""
        });

        // optin with same manager
        vm.broadcast(noCsm1);
        vm.expectRevert(DS.ManagerBelongsToOtherOperator.selector);
        cccp.optIn({
            moduleId: csmId,
            operatorId: noCsm1Id,
            manager: noCurated1Manager,
            newKeyIndexRangeStart: 2,
            newKeyIndexRangeEnd: 4,
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
            newKeyIndexRangeStart: 4,
            newKeyIndexRangeEnd: 2,
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
            newKeyIndexRangeStart: 2,
            newKeyIndexRangeEnd: 100,
            rpcURL: ""
        });
    }
}
