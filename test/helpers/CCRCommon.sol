// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Fixtures} from "./Fixtures.sol";
import {Utilities} from "./Utilities.sol";
import {LidoLocatorMock} from "test/helpers/mocks/LidoLocatorMock.sol";
import {StakingModuleMock} from "test/helpers/mocks/StakingModuleMock.sol";
import {StakingRouterMock} from "test/helpers/mocks/StakingRouterMock.sol";
import {CuratedModuleMock} from "test/helpers/mocks/CuratedModuleMock.sol";
import {CSModuleMock} from "test/helpers/mocks/CSModuleMock.sol";

abstract contract CCRFixtures is Test, Fixtures, Utilities {
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

    // uint64 optInDelayBlocks = 100;
    // uint64 optOutDelayBlocks = 200;
    // uint64 defaultOperatorMaxKeys = 100;
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

contract CCRCommon is CCRFixtures {
    function setUp() public virtual {
        committee = nextAddress("COMMITTEE");
        stranger1 = nextAddress("STRANGER1");
        stranger2 = nextAddress("STRANGER2");

        (locator, sr, nor, csm) = initLidoMock();
    }
}
