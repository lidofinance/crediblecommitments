// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Utilities} from "../../helpers/Utilities.sol";
import {DeploymentFixtures} from "../../helpers/Fixtures.sol";
import {DeployParams} from "../../../script/DeployBase.sol";
import {OssifiableProxy} from "../../../src/lib/proxy/OssifiableProxy.sol";
import {CCR} from "../../../src/CCR.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract CSModuleDeploymentTest is Test, Utilities, DeploymentFixtures {
    DeployParams private deployParams;

    function setUp() public {
        Env memory env = envVars();
        vm.createSelectFork(env.RPC_URL);
        initializeFromDeployment(env.DEPLOY_CONFIG);
        deployParams = parseDeployParams(env.DEPLOY_CONFIG);
    }

    function test_constructor() public view {
        assertEq(address(ccr.LIDO_LOCATOR()), deployParams.lidoLocatorAddress);
    }

    function test_initializer() public view {
        (uint64 optInDelayBlocks, uint64 optOutDelayBlocks, uint64 defaultOperatorMaxKeys, uint64 defaultBlockGasLimit)
        = ccr.getConfig();

        assertEq(optInDelayBlocks, deployParams.optInDelayBlocks);
        assertEq(optOutDelayBlocks, deployParams.optOutDelayBlocks);
        assertEq(defaultOperatorMaxKeys, deployParams.defaultOperatorMaxKeys);
        assertEq(defaultBlockGasLimit, deployParams.defaultBlockGasLimit);
        assertEq(ccr.getContractVersion(), 1);
        assertFalse(ccr.paused());
    }

    function test_roles() public view {
        assertTrue(ccr.hasRole(ccr.DEFAULT_ADMIN_ROLE(), deployParams.committeeAddress));
        assertTrue(ccr.getRoleMemberCount(ccr.DEFAULT_ADMIN_ROLE()) == 1);
        assertTrue(ccr.hasRole(ccr.PAUSE_ROLE(), deployParams.committeeAddress));
        assertTrue(ccr.hasRole(ccr.RESUME_ROLE(), deployParams.committeeAddress));
        assertEq(ccr.getRoleMemberCount(ccr.PAUSE_ROLE()), 1);
        assertEq(ccr.getRoleMemberCount(ccr.RESUME_ROLE()), 1);
    }

    function test_proxy() public {
        OssifiableProxy proxy = OssifiableProxy(payable(address(ccr)));
        assertEq(proxy.proxy__getAdmin(), address(deployParams.proxyAdmin));
        assertFalse(proxy.proxy__getIsOssified());

        CCR ccrImpl = CCR(proxy.proxy__getImplementation());
        assertEq(ccrImpl.getContractVersion(), type(uint64).max);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        ccr.initialize({
            committeeAddress: deployParams.committeeAddress,
            optInDelayBlocks: deployParams.optInDelayBlocks,
            optOutDelayBlocks: deployParams.optOutDelayBlocks,
            defaultOperatorMaxKeys: deployParams.defaultOperatorMaxKeys,
            defaultBlockGasLimit: deployParams.defaultBlockGasLimit
        });
    }
}
