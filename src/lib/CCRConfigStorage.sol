// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {ICCRConfigStorage} from "../interfaces/ICCRConfigStorage.sol";

abstract contract CCRConfigStorage is ICCRConfigStorage {
    bytes32 private immutable STORAGE_SLOT_REF;

    constructor() {
        STORAGE_SLOT_REF = keccak256(
            abi.encode(uint256(keccak256(abi.encodePacked("lido.ccr.storage.ConfigStorage"))) - 1)
        ) & ~bytes32(uint256(0xff));
    }

    function _setConfig(
        uint64 optInDelayBlocks,
        uint64 optOutDelayBlocks,
        uint64 defaultOperatorMaxKeys,
        uint64 defaultBlockGasLimit
    ) internal {
        if (defaultOperatorMaxKeys == 0) {
            revert ZeroDefaultOperatorMaxKeys();
        }
        if (defaultBlockGasLimit == 0) {
            revert ZeroDefaultBlockGasLimit();
        }
        _getConfigStorage()._config = Config({
            optInDelayBlocks: optInDelayBlocks,
            optOutDelayBlocks: optOutDelayBlocks,
            defaultOperatorMaxKeys: defaultOperatorMaxKeys,
            defaultBlockGasLimit: defaultBlockGasLimit
        });
    }

    function _setModuleConfig(uint24 moduleId, bool isDisabled, uint64 operatorMaxKeys, uint64 blockGasLimit)
        internal
    {
        _getConfigStorage()._modules[moduleId] =
            ModuleConfig({isDisabled: isDisabled, operatorMaxKeys: operatorMaxKeys, blockGasLimit: blockGasLimit});
    }

    function _getConfig()
        internal
        view
        returns (
            uint64 optInDelayBlocks,
            uint64 optOutDelayBlocks,
            uint64 defaultOperatorMaxKeys,
            uint64 defaultBlockGasLimit
        )
    {
        Config memory config = _getConfigStorage()._config;
        return (
            config.optInDelayBlocks,
            config.optOutDelayBlocks,
            config.defaultOperatorMaxKeys,
            config.defaultBlockGasLimit
        );
    }

    function _getModuleConfig(uint24 moduleId)
        internal
        view
        returns (bool isDisabled, uint64 operatorMaxKeys, uint64 blockGasLimit)
    {
        ModuleConfig memory moduleConfig = _getConfigStorage()._modules[moduleId];
        return (moduleConfig.isDisabled, moduleConfig.operatorMaxKeys, moduleConfig.blockGasLimit);
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
