// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

struct ModuleState {
    bool isActive;
    // hopefully, we won't need more than 2^64 validators
    uint64 maxValidators;
}

library ModulesDataStorage {
    // keccak256(abi.encode(uint256(keccak256("lido.cccp.ModuleState")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ModulesDataStorageLocation =
        0x1cb8b99dfeaf843f4827b821911728ca184fdda9204e44e69030785a3cd43d00;

    struct ModulesData {
        mapping(uint256 => ModuleState) _states;
    }

    function _getModulesDataStorage() private pure returns (ModulesData storage $) {
        assembly {
            $.slot := ModulesDataStorageLocation
        }
    }

    function _getModuleState(uint24 moduleId) internal view returns (ModuleState memory) {
        return _getModulesDataStorage()._states[moduleId];
    }

    function _setModuleState(uint24 moduleId, ModuleState memory state) internal {
        _getModulesDataStorage()._states[moduleId] = state;
    }
}
