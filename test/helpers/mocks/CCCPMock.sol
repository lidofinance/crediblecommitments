// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {CredibleCommitmentCurationProvider} from "../../../src/CredibleCommitmentCurationProvider.sol";

contract CCCPMock is CredibleCommitmentCurationProvider {
    constructor(address lidoLocator, bytes32 csModuleType)
        CredibleCommitmentCurationProvider(lidoLocator, csModuleType)
    {}

    function __test__getCSModuleType() external view returns (bytes32) {
        return CS_MODULE_TYPE;
    }

    function initialize_v2() external reinitializer(2) {
        _unpause();
    }
}
