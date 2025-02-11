// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {DeployBase} from "./DeployBase.sol";

contract DeployHolesky is DeployBase {
    constructor() DeployBase("holesky", 17000) {
        // implementation constants
        params.lidoLocatorAddress = 0x28FAB2059C713A7F9D8c86Db49f9bb0e96Af1ef8;
        params.csModuleType = "community-onchain-v1";
        params.defaultOperatorMaxKeys = 100;
        params.defaultBlockGasLimit = 1000000;

        // proxy
        params.proxyAdmin = 0x401FD888B5E41113B7c0C47725A742bbc3A083EF; // Dev team EOA

        // initial parameters
        params.committeeAddress = 0x401FD888B5E41113B7c0C47725A742bbc3A083EF; // Dev team EOA
        params.optInDelayBlocks = 32;
        params.optOutDelayBlocks = 64;

        _setUp();
    }
}
