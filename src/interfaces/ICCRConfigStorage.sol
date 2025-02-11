// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

/**
 * @title ICCRConfigStorage
 * @notice Interface for interacting with the storage and control config params.
 */
interface ICCRConfigStorage {
    /// @notice steaking module parameters
    /// @dev override global default values, zero values means use default config
    /// @param isDisabled is module disabled for pre-confs
    ///        operators in disabled modules are automatically considered as opted-out
    /// @param operatorMaxKeys maximum number of keys per operator
    /// @param blockGasLimit block gas limit
    struct ModuleConfig {
        bool isDisabled;
        uint64 operatorMaxKeys;
        uint64 blockGasLimit;
    }

    /// @notice global config parameters
    /// @param optInDelayBlocks minimum duration of the opt-in period in blocks
    /// @param optOutDelayBlocks delay in blocks before the operator can opt-in again after opt-out
    /// @param defaultOperatorMaxKeys default maximum number of keys per operator
    /// @param defaultBlockGasLimit default block gas limit
    struct Config {
        uint64 optInDelayBlocks;
        uint64 optOutDelayBlocks;
        uint64 defaultOperatorMaxKeys;
        uint64 defaultBlockGasLimit;
    }

    struct ConfigStorage {
        // module configs
        mapping(uint256 => ModuleConfig) _modules;
        // config
        Config _config;
    }

    error ZeroDefaultOperatorMaxKeys();
    error ZeroDefaultBlockGasLimit();
}
