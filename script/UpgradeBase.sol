// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {ScriptInit} from "./ScriptInit.sol";
import {JsonObj, Json} from "./utils/Json.sol";

import {OssifiableProxy} from "../src/lib/proxy/OssifiableProxy.sol";
import {CCCP} from "../src/CCCP.sol";
import {DeployParams} from "./DeployBase.sol";

abstract contract UpgradeBase is ScriptInit {
    DeployParams internal params;
    CCCP public cccp;

    error ArtifactsChainIdMismatch(uint256 actual, uint256 expected);

    constructor(string memory _chainName, uint256 _chainId) ScriptInit(_chainName, _chainId) {}

    function run() external {
        init();

        string memory artifactsPath = vm.envOr("DEPLOY_CONFIG", string(""));
        uint256 artifactsChainId;
        (artifactsChainId, cccp, params) = parseArtifacts(artifactsPath);

        if (chainId != artifactsChainId) {
            revert ArtifactsChainIdMismatch({actual: artifactsChainId, expected: chainId});
        }

        vm.startBroadcast(pk);
        {
            OssifiableProxy proxy = OssifiableProxy(payable(address(cccp)));

            // deploy new CCCP implementation with the same LidoLocator and CSModuleType
            CCCP cccpImpl = _deployImplementation(params);
            _upgradeProxy(proxy, cccpImpl, params);

            JsonObj memory deployJson = Json.newObj();
            deployJson.set("ChainId", chainId);
            deployJson.set("CCCPImpl", address(cccpImpl));
            deployJson.set("CCCP", address(cccp));
            deployJson.set("LidoLocator", params.lidoLocatorAddress);
            deployJson.set("DeployParams", abi.encode(params));
            vm.writeJson(deployJson.str, _deployJsonFilename());
        }

        vm.stopBroadcast();
    }

    function parseArtifacts(string memory artifactsPath) internal view returns (uint256, CCCP, DeployParams memory) {
        string memory artifactsJson = vm.readFile(artifactsPath);

        return (
            vm.parseJsonUint(artifactsJson, ".ChainId"),
            CCCP(vm.parseJsonAddress(artifactsJson, ".CCCP")),
            abi.decode(vm.parseJsonBytes(artifactsJson, ".DeployParams"), (DeployParams))
        );
    }

    /// @dev can be overridden to customize the upgrade process
    function _deployImplementation(DeployParams memory _params) internal virtual returns (CCCP) {
        return new CCCP(_params.lidoLocatorAddress, _params.csModuleType);
    }

    /// @dev can be overridden to customize the upgrade process
    function _upgradeProxy(OssifiableProxy _proxy, CCCP _impl, DeployParams memory _params) internal virtual {
        // upgrade proxy to new CCCP implementation
        _proxy.proxy__upgradeTo(address(_impl));
        // silent warning: unused variable
        _params;

        // example of calling a function on the new implementation
        // proxy.proxy__upgradeToAndCall(address(impl), abi.encodeCall(impl.initialize_v2, ()));
    }
}
