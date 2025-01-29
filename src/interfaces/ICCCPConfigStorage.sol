// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

/**
 * @title ICCCPConfigStorage
 * @notice Interface for interacting with the storage and control config params.
 */
interface ICCCPConfigStorage {
    /// @notice steaking module parameters
    /// @dev override global default values, zero values means use default config
    /// @param isDisabled is module disabled for pre-confs
    ///        operators in disabled modules are automatically considered as opted-out
    /// @param operatorMaxValidators maximum number of validators per operator
    /// @param blockGasLimit block gas limit
    struct ModuleConfig {
        bool isDisabled;
        uint64 operatorMaxValidators;
        uint64 blockGasLimit;
    }

    /// @notice global config parameters
    /// @param optInMinDurationBlocks minimum duration of the opt-in period in blocks
    /// @param optOutDelayDurationBlocks delay in blocks before the operator can opt-in again after opt-out
    /// @param defaultOperatorMaxValidators default maximum number of validators per operator
    /// @param defaultBlockGasLimit default block gas limit
    struct Config {
        uint64 optInMinDurationBlocks;
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
