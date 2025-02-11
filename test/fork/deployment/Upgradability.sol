// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {OssifiableProxy} from "../../../src/lib/proxy/OssifiableProxy.sol";
import {CCRMock} from "../../helpers/mocks/CCRMock.sol";
import {DeploymentFixtures} from "../../helpers/Fixtures.sol";

contract UpgradabilityTest is Test, DeploymentFixtures {
    constructor() {
        Env memory env = envVars();
        vm.createSelectFork(env.RPC_URL);
        initializeFromDeployment(env.DEPLOY_CONFIG);
    }

    function test_CCRUpgradeTo() public {
        OssifiableProxy proxy = OssifiableProxy(payable(address(ccr)));
        CCRMock newCcr = new CCRMock(address(ccr.LIDO_LOCATOR()), "csm-type-new");

        vm.prank(proxy.proxy__getAdmin());
        proxy.proxy__upgradeTo(address(newCcr));
        assertEq(CCRMock(address(ccr)).__test__getCSModuleType(), "csm-type-new");
    }

    function test_CCRUpgradeToAndCall() public {
        OssifiableProxy proxy = OssifiableProxy(payable(address(ccr)));
        CCRMock newCcr = new CCRMock(address(ccr.LIDO_LOCATOR()), "csm-type-new");

        address contractAdmin = ccr.getRoleMember(ccr.DEFAULT_ADMIN_ROLE(), 0);
        vm.prank(contractAdmin);
        ccr.pause();
        assertTrue(ccr.paused());

        vm.prank(proxy.proxy__getAdmin());
        proxy.proxy__upgradeToAndCall(address(newCcr), abi.encodeCall(newCcr.initialize_v2, ()));
        assertEq(CCRMock(address(ccr)).__test__getCSModuleType(), "csm-type-new");
        assertEq(ccr.getContractVersion(), 2);
        assertFalse(ccr.paused());
    }
}
