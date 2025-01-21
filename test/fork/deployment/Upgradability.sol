// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {OssifiableProxy} from "../../../src/lib/proxy/OssifiableProxy.sol";
import {CCCPMock} from "../../helpers/mocks/CCCPMock.sol";
import {DeploymentFixtures} from "../../helpers/Fixtures.sol";

contract UpgradabilityTest is Test, DeploymentFixtures {
    constructor() {
        Env memory env = envVars();
        vm.createSelectFork(env.RPC_URL);
        initializeFromDeployment(env.DEPLOY_CONFIG);
    }

    function test_CCCPUpgradeTo() public {
        OssifiableProxy proxy = OssifiableProxy(payable(address(cccp)));
        CCCPMock newCccp = new CCCPMock(address(cccp.LIDO_LOCATOR()), "csm-type-new");

        vm.prank(proxy.proxy__getAdmin());
        proxy.proxy__upgradeTo(address(newCccp));
        assertEq(CCCPMock(address(cccp)).__test__getCSModuleType(), "csm-type-new");
    }

    function test_CCCPUpgradeToAndCall() public {
        OssifiableProxy proxy = OssifiableProxy(payable(address(cccp)));
        CCCPMock newCccp = new CCCPMock(address(cccp.LIDO_LOCATOR()), "csm-type-new");

        address contractAdmin = cccp.getRoleMember(cccp.DEFAULT_ADMIN_ROLE(), 0);
        vm.prank(contractAdmin);
        cccp.pause();
        assertTrue(cccp.paused());

        vm.prank(proxy.proxy__getAdmin());
        proxy.proxy__upgradeToAndCall(address(newCccp), abi.encodeCall(newCccp.initialize_v2, ()));
        assertEq(CCCPMock(address(cccp)).__test__getCSModuleType(), "csm-type-new");
        assertEq(cccp.getContractVersion(), 2);
        assertFalse(cccp.paused());
    }
}
