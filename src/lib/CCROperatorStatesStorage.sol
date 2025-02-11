// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ICCROperatorStatesStorage} from "../interfaces/ICCROperatorStatesStorage.sol";

abstract contract CCROperatorStatesStorage is ICCROperatorStatesStorage, Initializable {
    bytes32 private immutable STORAGE_SLOT_REF;

    constructor() {
        STORAGE_SLOT_REF = keccak256(
            abi.encode(uint256(keccak256(abi.encodePacked("lido.ccr.storage.OperatorStatesStorage"))) - 1)
        ) & ~bytes32(uint256(0xff));
    }

    function __initializeOperatorStatesStorage() internal onlyInitializing {}

    function _addOperatorCommitment(uint256 opKey, uint64 indexStart, uint64 indexEnd, string memory rpcUrl) internal {
        Commitment[] storage commitments = _getOperatorCommitmentsStorage(opKey);
        commitments.push(
            Commitment({id: bytes32(0), keyRange: KeyRange(indexStart, indexEnd), extraData: ExtraData(rpcUrl)})
        );
    }

    function _delOperatorCommitment(uint256 opKey, uint256 cIdx) internal {
        Commitment[] storage commitments = _getOperatorCommitmentsStorage(opKey);
        uint256 length = commitments.length;
        if (cIdx >= length) {
            revert IndexOutOfRange();
        }

        // del element in O(1), by replacing it with the last one
        unchecked {
            if (cIdx < length - 1) {
                commitments[cIdx] = commitments[length - 1];
            }
        }
        commitments.pop();
    }

    function _delOperatorAllCommitments(uint256 opKey) internal {
        if (_getOperatorCommitmentsStorage(opKey).length > 0) {
            delete _getOperatorStateStorage(opKey).commitments;
        }
    }

    function _addOperatorDelegate(uint256 opKey, bytes memory key) internal {
        Delegate[] storage delegates = _getOperatorDelegatesStorage(opKey);
        delegates.push(Delegate({key: key}));
    }

    function _delOperatorDelegate(uint256 opKey, uint256 dIdx) internal {
        Delegate[] storage delegates = _getOperatorDelegatesStorage(opKey);
        uint256 length = delegates.length;
        if (dIdx >= length) {
            revert IndexOutOfRange();
        }

        // del element in O(1), by replacing it with the last one
        unchecked {
            if (dIdx < length - 1) {
                delegates[dIdx] = delegates[length - 1];
            }
        }
        delegates.pop();
    }

    function _setOperatorCommitmentRPCUrl(uint256 opKey, uint256 cIdx, string memory rpcUrl) internal {
        _getOperatorCommitmentStorage(opKey, cIdx).extraData = ExtraData({rpcURL: rpcUrl});
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

    function _getOperatorOptInOutStateStorage(uint256 opKey) internal view returns (OptInOutState storage) {
        return _getOperatorStateStorage(opKey).optInOutState;
    }

    function _setOperatorOptInOutState(uint256 opKey, OptInOutState memory state) internal {
        _getOperatorStateStorage(opKey).optInOutState = state;
    }

    /// @notice get operator's extra data
    function _getOperatorCommitmentsStorage(uint256 opKey) internal view returns (Commitment[] storage) {
        return _getOperatorStateStorage(opKey).commitments;
    }

    function _getOperatorCommitmentStorage(uint256 opKey, uint256 cIdx) internal view returns (Commitment storage) {
        // return _getOperatorStateStorage(opKey).commitments[cIdx];
        return _getOperatorCommitmentsStorage(opKey)[cIdx];
    }

    function _getOperatorDelegatesStorage(uint256 opKey) internal view returns (Delegate[] storage) {
        return _getOperatorStateStorage(opKey).delegates;
    }

    function _getOperatorDelegateStorage(uint256 opKey, uint256 dIdx) internal view returns (Delegate storage) {
        return _getOperatorDelegatesStorage(opKey)[dIdx];
    }

    // function _getOperatorCommitmentExtraData(uint256 opKey, uint cIdx) internal view returns (ExtraData memory) {
    //     Commitment[] storage commitments = _getOperatorStateStorage(opKey).commitments;
    //     return commitments[cIdx].extraData;
    // }

    /// @notice get manager address linked to the operator's reward address
    function _getOperatorManager(uint256 opKey) internal view returns (address) {
        return _getOperatorStateStorage(opKey).manager;
    }

    function _getIsOperatorBlocked(uint256 opKey) internal view returns (bool) {
        return _getOperatorStateStorage(opKey).isBlocked;
    }

    function _setIsOperatorBlocked(uint256 opKey, bool isBlocked) internal {
        _getOperatorStateStorage(opKey).isBlocked = isBlocked;
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
