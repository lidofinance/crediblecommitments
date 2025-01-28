// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";

abstract contract ScriptInit is Script {
    string internal artifactDir;
    string internal chainName;
    uint256 internal chainId;
    address internal deployer;
    uint256 internal pk;

    error ChainIdMismatch(uint256 actual, uint256 expected);

    constructor(string memory _chainName, uint256 _chainId) {
        chainName = _chainName;
        chainId = _chainId;
    }

    function _setUp() internal virtual {}

    function init() internal virtual {
        if (chainId != block.chainid) {
            revert ChainIdMismatch({actual: block.chainid, expected: chainId});
        }

        artifactDir = vm.envOr("ARTIFACTS_DIR", string("./artifacts/local/"));
        pk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(pk);
        vm.label(deployer, "DEPLOYER");
    }

    function _deployJsonFilename() internal view returns (string memory) {
        return string(abi.encodePacked(artifactDir, "deploy-", chainName, ".json"));
    }
}
