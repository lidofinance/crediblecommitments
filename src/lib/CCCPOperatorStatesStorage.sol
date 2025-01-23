// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ICCCPOperatorStatesStorage} from "../interfaces/ICCCPOperatorStatesStorage.sol";

abstract contract CCCPOperatorStatesStorage is ICCCPOperatorStatesStorage, Initializable {
    bytes32 private immutable STORAGE_SLOT_REF;

    constructor() {
        STORAGE_SLOT_REF = keccak256(
            abi.encode(uint256(keccak256(abi.encodePacked("lido.cccp.storage.OperatorStatesStorage"))) - 1)
        ) & ~bytes32(uint256(0xff));
    }

    function __initializeOperatorStatesStorage() internal onlyInitializing {}

    function _setOperatorOptInOutState(uint256 opKey, OptInOutState memory state) internal {
        _getOperatorStateStorage(opKey).optInOutState = state;
    }

    function _setOperatorKeysRange(uint256 opKey, uint64 indexStart, uint64 indexEnd) internal {
        _getOperatorStateStorage(opKey).keysRange = KeysRange(indexStart, indexEnd);
    }

    function _setOperatorExtraData(uint256 opKey, ExtraData memory data) internal {
        _getOperatorStateStorage(opKey).extraData = data;
    }

    /// @dev safe manager's address update
    function _setOperatorManager(uint256 opKey, address manager) internal {
        // _checkManagerFree(opKey, manager);
        uint256 managerOpKey = _getManagerOpKey(manager);
        // revert if the manager address is linked to the other operator
        if (managerOpKey != 0 && managerOpKey != opKey) {
            revert ManagerBelongsToOtherOperator();
        }

        OperatorState storage $ = _getOperatorStateStorage(opKey);
        address oldManager = $.manager;
        if (oldManager != address(0) && oldManager != manager) {
            delete _getOperatorsStatesStorage()._managers[oldManager];
        }
        $.manager = manager;
        _getOperatorsStatesStorage()._managers[manager] = opKey;
    }

    /// @notice get operator' full state
    function _getOperatorState(uint256 opKey) internal view returns (OperatorState memory) {
        return _getOperatorStateStorage(opKey);
    }

    /// @notice get operator's opt-in/opt-out state
    function _getOperatorOptInOutState(uint256 opKey) internal view returns (OptInOutState memory) {
        return _getOperatorStateStorage(opKey).optInOutState;
    }

    /// @notice get operator's keys range state
    function _getOperatorKeysRange(uint256 opKey) internal view returns (KeysRange memory) {
        return _getOperatorStateStorage(opKey).keysRange;
    }

    /// @notice get operator's extra data
    function _getOperatorExtraData(uint256 opKey) internal view returns (ExtraData memory) {
        return _getOperatorStateStorage(opKey).extraData;
    }

    /// @notice get manager address linked to the operator's reward address
    function _getOperatorManager(uint256 opKey) internal view returns (address managerAddress) {
        return _getOperatorStateStorage(opKey).manager;
    }

    function _getManagerOpKey(address manager) internal view returns (uint256) {
        return _getOperatorsStatesStorage()._managers[manager];
    }

    /// @dev reverts if the operator not registered
    function _getOpKeyById(uint24 moduleId, uint64 operatorId) internal view returns (uint256 opKey) {
        opKey = __encOpKey(moduleId, operatorId);
        if (_getOperatorManager(opKey) == address(0)) {
            revert OperatorNotRegistered();
        }
    }

    function _getOpKeyByManager(address manager) internal view returns (uint256 opKey) {
        opKey = _getManagerOpKey(manager);
        if (opKey == 0) {
            revert ManagerNotRegistered();
        }
    }

    function __encOpKey(uint24 moduleId, uint64 operatorId) internal pure returns (uint256) {
        return (uint256(moduleId) << 64) | operatorId;
    }

    function __decOpKey(uint256 opKey) internal pure returns (uint24 moduleId, uint64 operatorId) {
        return (uint24(opKey >> 64), uint64(opKey));
    }

    /**
     * @notice Accesses the storage slot for the OperatorState's data.
     * @return $ A reference to the `OperatorsStatesStorage` struct.
     *
     * @dev This function uses inline assembly to access a predefined storage slot.
     */
    function _getOperatorsStatesStorage() private view returns (OperatorsStatesStorage storage $) {
        bytes32 slot = STORAGE_SLOT_REF;
        assembly {
            $.slot := slot
        }
    }

    function _getOperatorStateStorage(uint256 opKey) private view returns (OperatorState storage) {
        return _getOperatorsStatesStorage()._operators[opKey];
    }
}
