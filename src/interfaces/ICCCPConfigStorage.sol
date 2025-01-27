// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

/**
 * @title ICCCPConfigStorage
 * @notice Interface for interacting with the storage and control config params.
 */
interface ICCCPConfigStorage {
    struct ModuleConfig {
        // hopefully, we won't need more than 2^64 validators
        /// @dev zero value means use default config
        uint64 maxValidators;
        // is module disabled for pre-confs
        /// @dev operators in disabled modules are automatically considered as opted-out
        bool isDisabled;
    }

    struct Config {
        // minimum duration of the opt-in period in blocks
        uint64 optInMinDurationBlocks;
        // delay in blocks before the operator can opt-in again after opt-out
        uint64 optOutDelayDurationBlocks;
        uint64 defaultOperatorMaxValidators;
        uint64 defaultBlockGasLimit;
    }

    struct ConfigStorage {
        // module configs
        mapping(uint256 => ModuleConfig) _modules;
        // config
        Config _config;
    }

    error ZeroDefaultOperatorMaxValidators();
    error ZeroDefaultBlockGasLimit();
}
