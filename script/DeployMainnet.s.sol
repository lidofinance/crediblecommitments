// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {DeployBase} from "./DeployBase.s.sol";

contract DeployMainnet is DeployBase {
    constructor() DeployBase("mainnet", 1) {
        // implementation constants
        config.lidoLocatorAddress = 0xC1d0b3DE6792Bf6b4b37EccdcC24e45978Cfd2Eb;
        config.csModuleType = "community-onchain-v1";
        config.defaultOperatorMaxValidators = 1000;
        config.defaultBlockGasLimit = 3000000;

        // proxy
        config.proxyAdmin = 0x0000000000000000000000000000000000000000; // Dev team EOA

        // initial parameters
        config.committeeAddress = 0x0000000000000000000000000000000000000000; // Dev team EOA
        config.optInMinDurationBlocks = 0;
        config.optOutDelayDurationBlocks = 64;

        _setUp();
    }
}
