// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

import {StdCheats} from "forge-std/StdCheats.sol";
import {Test} from "forge-std/Test.sol";

import {DeployParams} from "../../script/DeployBase.sol";
import {CCR} from "../../src/CCR.sol";

import {ILidoLocator} from "../../src/interfaces/ILidoLocator.sol";
import {IStakingRouter} from "../../src/interfaces/IStakingRouter.sol";

import {LidoLocatorMock} from "./mocks/LidoLocatorMock.sol";
import {StakingRouterMock} from "./mocks/StakingRouterMock.sol";
import {CuratedModuleMock} from "./mocks/CuratedModuleMock.sol";
import {CSModuleMock} from "./mocks/CSModuleMock.sol";

contract Fixtures is StdCheats, Test {
    bytes32 public constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    function initLidoMock()
        public
        returns (LidoLocatorMock locator, StakingRouterMock sr, CuratedModuleMock nor, CSModuleMock csm)
    {
        csm = new CSModuleMock();
        nor = new CuratedModuleMock();
        sr = new StakingRouterMock();

        // add modules to SR
        sr.addModule(address(nor));
        sr.addModule(address(csm));

        locator = new LidoLocatorMock(address(sr));

        vm.label(address(csm), "csm");
        vm.label(address(nor), "nor");
        vm.label(address(locator), "locator");
        vm.label(address(sr), "stakingRouter");
    }

    function _enableInitializers(address implementation) internal {
        // cheat to allow implementation initialisation
        vm.store(implementation, INITIALIZABLE_STORAGE, bytes32(0));
    }
}

contract DeploymentFixtures is StdCheats, Test {
    struct Env {
        string RPC_URL;
        string DEPLOY_CONFIG;
    }

    struct DeploymentConfig {
        uint256 chainId;
        address ccr;
        address lidoLocator;
    }

    CCR public ccr;
    ILidoLocator public locator;
    IStakingRouter public stakingRouter;

    function envVars() public returns (Env memory) {
        Env memory env = Env(vm.envOr("RPC_URL", string("")), vm.envOr("DEPLOY_CONFIG", string("")));
        vm.skip(_isEmpty(env.RPC_URL));
        vm.skip(_isEmpty(env.DEPLOY_CONFIG));
        return env;
    }

    function initializeFromDeployment(string memory deployConfigPath) public {
        string memory config = vm.readFile(deployConfigPath);
        DeploymentConfig memory deploymentConfig = parseDeploymentConfig(config);
        assertEq(deploymentConfig.chainId, block.chainid, "ChainId mismatch");

        ccr = CCR(deploymentConfig.ccr);
        locator = ILidoLocator(deploymentConfig.lidoLocator);
        stakingRouter = IStakingRouter(locator.stakingRouter());
    }

    function parseDeploymentConfig(string memory config) public returns (DeploymentConfig memory deploymentConfig) {
        deploymentConfig.chainId = vm.parseJsonUint(config, ".ChainId");

        deploymentConfig.ccr = vm.parseJsonAddress(config, ".CCR");
        vm.label(deploymentConfig.ccr, "csm");

        deploymentConfig.lidoLocator = vm.parseJsonAddress(config, ".LidoLocator");
        vm.label(deploymentConfig.lidoLocator, "LidoLocator");
    }

    function parseDeployParams(string memory deployConfigPath) internal view returns (DeployParams memory) {
        string memory config = vm.readFile(deployConfigPath);
        return abi.decode(vm.parseJsonBytes(config, ".DeployParams"), (DeployParams));
    }

    function _isEmpty(string memory s) internal pure returns (bool) {
        return keccak256(abi.encodePacked(s)) == keccak256(abi.encodePacked(""));
    }
}
