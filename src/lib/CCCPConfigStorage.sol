// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {ICCCPConfigStorage} from "../interfaces/ICCCPConfigStorage.sol";

abstract contract CCCPConfigStorage is ICCCPConfigStorage {
    bytes32 private immutable STORAGE_SLOT_REF;

    constructor() {
        STORAGE_SLOT_REF = keccak256(
            abi.encode(uint256(keccak256(abi.encodePacked("lido.cccp.storage.ConfigStorage"))) - 1)
        ) & ~bytes32(uint256(0xff));
    }

    function _setConfig(
        uint64 optInMinDurationBlocks,
        uint64 optOutDelayDurationBlocks,
        uint64 defaultOperatorMaxValidators,
        uint64 defaultBlockGasLimit
    ) internal {
        if (defaultOperatorMaxValidators == 0) {
            revert ZeroDefaultOperatorMaxValidators();
        }
        if (defaultBlockGasLimit == 0) {
            revert ZeroDefaultBlockGasLimit();
        }
        _getConfigStorage()._config = Config({
            optInMinDurationBlocks: optInMinDurationBlocks,
            optOutDelayDurationBlocks: optOutDelayDurationBlocks,
            defaultOperatorMaxValidators: defaultOperatorMaxValidators,
            defaultBlockGasLimit: defaultBlockGasLimit
        });
    }

    function _setModuleConfig(uint24 moduleId, uint64 maxValidators, bool isDisabled) internal {
        _getConfigStorage()._modules[moduleId] = ModuleConfig({maxValidators: maxValidators, isDisabled: isDisabled});
    }

    function _getConfig()
        internal
        view
        returns (
            uint64 optInMinDurationBlocks,
            uint64 optOutDelayDurationBlocks,
            uint64 defaultOperatorMaxValidators,
            uint64 defaultBlockGasLimit
        )
    {
        Config memory config = _getConfigStorage()._config;
        return (
            config.optInMinDurationBlocks,
            config.optOutDelayDurationBlocks,
            config.defaultOperatorMaxValidators,
            config.defaultBlockGasLimit
        );
    }

    function _getModuleConfig(uint24 moduleId) internal view returns (uint64 maxValidators, bool isDisabled) {
        ModuleConfig memory moduleConfig = _getConfigStorage()._modules[moduleId];
        return (moduleConfig.maxValidators, moduleConfig.isDisabled);
    }

    /**
     * @notice Accesses the storage slot for the config's data.
     * @return $ A reference to the `ConfigStorage` struct.
     *
     * @dev This function uses inline assembly to access a predefined storage slot.
     */
    function _getConfigStorage() private view returns (ConfigStorage storage $) {
        bytes32 slot = STORAGE_SLOT_REF;
        assembly {
            $.slot := slot
        }
    }
}
