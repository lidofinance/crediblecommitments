// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Utilities} from "../../helpers/Utilities.sol";
import {DeploymentFixtures} from "../../helpers/Fixtures.sol";
import {DeployParams} from "../../../script/DeployBase.sol";
import {OssifiableProxy} from "../../../src/lib/proxy/OssifiableProxy.sol";
import {CCCP} from "../../../src/CCCP.sol";
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
        assertEq(address(cccp.LIDO_LOCATOR()), deployParams.lidoLocatorAddress);
    }

    function test_initializer() public view {
        (
            uint64 optInMinDurationBlocks,
            uint64 optOutDelayDurationBlocks,
            uint64 defaultOperatorMaxValidators,
            uint64 defaultBlockGasLimit
        ) = cccp.getConfig();

        assertEq(optInMinDurationBlocks, deployParams.optInMinDurationBlocks);
        assertEq(optOutDelayDurationBlocks, deployParams.optOutDelayDurationBlocks);
        assertEq(defaultOperatorMaxValidators, deployParams.defaultOperatorMaxValidators);
        assertEq(defaultBlockGasLimit, deployParams.defaultBlockGasLimit);
        assertEq(cccp.getContractVersion(), 1);
        assertFalse(cccp.paused());
    }

    function test_roles() public view {
        assertTrue(cccp.hasRole(cccp.DEFAULT_ADMIN_ROLE(), deployParams.committeeAddress));
        assertTrue(cccp.getRoleMemberCount(cccp.DEFAULT_ADMIN_ROLE()) == 1);
        assertTrue(cccp.hasRole(cccp.PAUSE_ROLE(), deployParams.committeeAddress));
        assertTrue(cccp.hasRole(cccp.RESUME_ROLE(), deployParams.committeeAddress));
        assertEq(cccp.getRoleMemberCount(cccp.PAUSE_ROLE()), 1);
        assertEq(cccp.getRoleMemberCount(cccp.RESUME_ROLE()), 1);
    }

    function test_proxy() public {
        OssifiableProxy proxy = OssifiableProxy(payable(address(cccp)));
        assertEq(proxy.proxy__getAdmin(), address(deployParams.proxyAdmin));
        assertFalse(proxy.proxy__getIsOssified());

        CCCP cccpImpl = CCCP(proxy.proxy__getImplementation());
        assertEq(cccpImpl.getContractVersion(), type(uint64).max);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        cccp.initialize({
            committeeAddress: deployParams.committeeAddress,
            optInMinDurationBlocks: deployParams.optInMinDurationBlocks,
            optOutDelayDurationBlocks: deployParams.optOutDelayDurationBlocks,
            defaultOperatorMaxValidators: deployParams.defaultOperatorMaxValidators,
            defaultBlockGasLimit: deployParams.defaultBlockGasLimit
        });
    }
}
