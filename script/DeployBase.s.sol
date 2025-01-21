// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {OssifiableProxy} from "../src/lib/proxy/OssifiableProxy.sol";
import {CredibleCommitmentCurationProvider} from "../src/CredibleCommitmentCurationProvider.sol";

import {JsonObj, Json} from "./utils/Json.sol";

struct DeployParams {
    address lidoLocatorAddress;
    bytes32 csModuleType;
    address proxyAdmin;
    address committeeAddress;
    uint64 optInMinDurationBlocks;
    uint64 optOutDelayDurationBlocks;
    uint64 defaultOperatorMaxValidators;
    uint64 defaultBlockGasLimit;
}

abstract contract DeployBase is Script {
    DeployParams internal config;
    string internal artifactDir;
    string internal chainName;
    uint256 internal chainId;

    address internal deployer;
    uint256 internal pk;
    CredibleCommitmentCurationProvider public cccp;

    error ChainIdMismatch(uint256 actual, uint256 expected);

    constructor(string memory _chainName, uint256 _chainId) {
        chainName = _chainName;
        chainId = _chainId;
    }

    function _setUp() internal {}

    function run() external virtual {
        if (chainId != block.chainid) {
            revert ChainIdMismatch({actual: block.chainid, expected: chainId});
        }

        artifactDir = vm.envOr("ARTIFACTS_DIR", string("./artifacts/local/"));
        pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(pk);
        vm.label(deployer, "DEPLOYER");

        vm.startBroadcast(pk);
        {
            address cccpImpl =
                address(new CredibleCommitmentCurationProvider(config.lidoLocatorAddress, config.csModuleType));

            cccp = CredibleCommitmentCurationProvider(
                _deployProxy(
                    config.proxyAdmin,
                    address(cccpImpl),
                    abi.encodeCall(
                        CredibleCommitmentCurationProvider.initialize,
                        (
                            config.committeeAddress,
                            config.optInMinDurationBlocks,
                            config.optOutDelayDurationBlocks,
                            config.defaultOperatorMaxValidators,
                            config.defaultBlockGasLimit
                        )
                    )
                )
            );

            JsonObj memory deployJson = Json.newObj();
            deployJson.set("ChainId", chainId);
            deployJson.set("CCCPImpl", cccpImpl);
            deployJson.set("CCCP", address(cccp));
            deployJson.set("LidoLocator", config.lidoLocatorAddress);
            deployJson.set("DeployParams", abi.encode(config));
            vm.writeJson(deployJson.str, _deployJsonFilename());
        }

        vm.stopBroadcast();
    }

    function _deployProxy(address admin, address implementation, bytes memory data) internal returns (address) {
        OssifiableProxy proxy = new OssifiableProxy({implementation_: implementation, data_: data, admin_: admin});

        return address(proxy);
    }

    function _deployJsonFilename() internal view returns (string memory) {
        return string(abi.encodePacked(artifactDir, "deploy-", chainName, ".json"));
    }
}
