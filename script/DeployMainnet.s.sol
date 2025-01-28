// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {DeployBase} from "./DeployBase.sol";

contract DeployMainnet is DeployBase {
    constructor() DeployBase("mainnet", 1) {
        // implementation constants
        params.lidoLocatorAddress = 0xC1d0b3DE6792Bf6b4b37EccdcC24e45978Cfd2Eb;
        params.csModuleType = "community-onchain-v1";
        params.defaultOperatorMaxValidators = 1000;
        params.defaultBlockGasLimit = 3000000;

        // proxy
        params.proxyAdmin = 0x0000000000000000000000000000000000000000; // Dev team EOA

        // initial parameters
        params.committeeAddress = 0x0000000000000000000000000000000000000000; // Dev team EOA
        params.optInMinDurationBlocks = 0;
        params.optOutDelayDurationBlocks = 64;

        _setUp();
    }
}
