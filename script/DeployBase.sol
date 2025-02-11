// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {ScriptInit} from "./ScriptInit.sol";
import {JsonObj, Json} from "./utils/Json.sol";

import {OssifiableProxy} from "../src/lib/proxy/OssifiableProxy.sol";
import {CCR} from "../src/CCR.sol";

struct DeployParams {
    address lidoLocatorAddress;
    bytes32 csModuleType;
    address proxyAdmin;
    address committeeAddress;
    uint64 optInDelayBlocks;
    uint64 optOutDelayBlocks;
    uint64 defaultOperatorMaxKeys;
    uint64 defaultBlockGasLimit;
}

abstract contract DeployBase is ScriptInit {
    DeployParams public params;
    CCR public ccr;

    constructor(string memory _chainName, uint256 _chainId) ScriptInit(_chainName, _chainId) {}

    function run() external virtual {
        init();

        vm.startBroadcast(pk);
        {
            // deploy new CCR implementation
            CCR ccrImpl = _deployImplementation(params);

            ccr = CCR(
                _deployProxy(
                    params.proxyAdmin,
                    address(ccrImpl),
                    abi.encodeCall(
                        CCR.initialize,
                        (
                            params.committeeAddress,
                            params.optInDelayBlocks,
                            params.optOutDelayBlocks,
                            params.defaultOperatorMaxKeys,
                            params.defaultBlockGasLimit
                        )
                    )
                )
            );

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

    /// @dev can be overridden to customize the upgrade process
    function _deployImplementation(DeployParams memory _params) internal virtual returns (CCR) {
        return new CCR(_params.lidoLocatorAddress, _params.csModuleType);
    }

    function _deployProxy(address _admin, address _impl, bytes memory _data) internal returns (address) {
        OssifiableProxy proxy = new OssifiableProxy({implementation_: _impl, data_: _data, admin_: _admin});

        return address(proxy);
    }
}
