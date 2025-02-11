// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {ScriptInit} from "./ScriptInit.sol";
import {JsonObj, Json} from "./utils/Json.sol";

import {OssifiableProxy} from "../src/lib/proxy/OssifiableProxy.sol";
import {CCR} from "../src/CCR.sol";
import {DeployParams} from "./DeployBase.sol";

abstract contract UpgradeBase is ScriptInit {
    DeployParams internal params;
    CCR public ccr;

    error ArtifactsChainIdMismatch(uint256 actual, uint256 expected);

    constructor(string memory _chainName, uint256 _chainId) ScriptInit(_chainName, _chainId) {}

    function run() external {
        init();

        string memory artifactsPath = vm.envOr("DEPLOY_CONFIG", string(""));
        uint256 artifactsChainId;
        (artifactsChainId, ccr, params) = parseArtifacts(artifactsPath);

        if (chainId != artifactsChainId) {
            revert ArtifactsChainIdMismatch({actual: artifactsChainId, expected: chainId});
        }

        vm.startBroadcast(pk);
        {
            OssifiableProxy proxy = OssifiableProxy(payable(address(ccr)));

            // deploy new CCR implementation with the same LidoLocator and CSModuleType
            CCR ccrImpl = _deployImplementation(params);
            _upgradeProxy(proxy, ccrImpl, params);

            JsonObj memory deployJson = Json.newObj();
            deployJson.set("ChainId", chainId);
            deployJson.set("CCRImpl", address(ccrImpl));
            deployJson.set("CCR", address(ccr));
            deployJson.set("LidoLocator", params.lidoLocatorAddress);
            deployJson.set("DeployParams", abi.encode(params));
            vm.writeJson(deployJson.str, _deployJsonFilename());
        }

        vm.stopBroadcast();
    }

    function parseArtifacts(string memory artifactsPath) internal view returns (uint256, CCR, DeployParams memory) {
        string memory artifactsJson = vm.readFile(artifactsPath);

        return (
            vm.parseJsonUint(artifactsJson, ".ChainId"),
            CCR(vm.parseJsonAddress(artifactsJson, ".CCR")),
            abi.decode(vm.parseJsonBytes(artifactsJson, ".DeployParams"), (DeployParams))
        );
    }

    /// @dev can be overridden to customize the upgrade process
    function _deployImplementation(DeployParams memory _params) internal virtual returns (CCR) {
        return new CCR(_params.lidoLocatorAddress, _params.csModuleType);
    }

    /// @dev can be overridden to customize the upgrade process
    function _upgradeProxy(OssifiableProxy _proxy, CCR _impl, DeployParams memory _params) internal virtual {
        // upgrade proxy to new CCR implementation
        _proxy.proxy__upgradeTo(address(_impl));
        // silent warning: unused variable
        _params;

        // example of calling a function on the new implementation
        // proxy.proxy__upgradeToAndCall(address(impl), abi.encodeCall(impl.initialize_v2, ()));
    }
}
