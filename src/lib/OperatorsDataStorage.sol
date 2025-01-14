// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

/// @notice operator optin/optout state
/// operator can be in several statuses:
// 1. new, not registered: optInBlock = 0, optOutBlock = 0
// 2. registered: optInBlock > 0, optOutBlock = 0
// 3. opt-out in progress: optInBlock > 0, optOutBlock > 0, optOutBlock + optOutDelayDurationBlocksDelay >= block.r
// 4. forded opt-out in progress: optInBlock > 0, optOutBlock > 0, isOptOutForced = true, optOutBlock + optOutDelayDurationBlocksDelay >= block.r
// 5. opt-out completed: optInBlock > 0, optOutBlock > 0, isOptOutForced = false, optOutBlock + optOutDelayDurationBlocksDelay < block.r
// 6. forced opt-out completed: optInBlock > 0, optOutBlock > 0, isOptOutForced = true, optOutBlock + optOutDelayDurationBlocksDelay < block.r

// If isOptOutForced is set, optOutBlock has non-zero value of the block number when the operator was forced to opt out.
// If operator has "forced opt-out completed" status, it can't opt in again until the committee decides to allow it (clear isOptOutForced flag).
struct OperatorOptInOutState {
    uint64 optInBlock;
    uint64 optOutBlock;
    bool isOptOutForced; // if the operator is forced to opt out by the committee
}

struct OperatorKeysRangeState {
    uint64 indexStart;
    uint64 indexEnd;
}

struct OperatorAttributes {
    uint24 moduleId;
    uint64 operatorId;
}
// address managerAddress;

struct OperatorExtraData {
    string rpcURL;
}

struct OperatorState {
    // 1st slot
    OperatorAttributes attr;
    // 2nd slot
    OperatorOptInOutState optInOutState;
    // 3rd slot
    OperatorKeysRangeState keysRangeState;
    // 4+ slots
    OperatorExtraData extraData;
}

library OperatorsDataStorage {
    // keccak256(abi.encode(uint256(keccak256("lido.cccp.OperatorsData")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OperatorsDataStorageLocation =
        0x431bec91c9e23dd28793baaf52dfc0abbbc039dfe7dd0289d5cfb3a490da5600;

    struct OperatorsData {
        mapping(address => OperatorState) _states;
        // operator's manager to reward address mapping, allow operators not use their reward address
        mapping(address => address) _managers;
    }

    function _getOperatorsDataStorage() private pure returns (OperatorsData storage $) {
        assembly {
            $.slot := OperatorsDataStorageLocation
        }
    }

    function _getOperatorStateStorage(address managerAddress) private view returns (OperatorState storage) {
        return _getOperatorsDataStorage()._states[managerAddress];
    }

    /// @notice get operator' full state
    function _getOperatorState(address managerAddress) internal view returns (OperatorState memory) {
        return _getOperatorsDataStorage()._states[managerAddress];
    }

    // function _setOperatorState(address managerAddress, OperatorState memory state) internal {
    //     _getOperatorsDataStorage()._states[managerAddress] = operator;
    // }

    /// @notice get operator's attributes
    function _getOperatorAttributes(address managerAddress) internal view returns (OperatorAttributes memory) {
        return _getOperatorStateStorage(managerAddress).attr;
    }

    function _setOperatorAttributes(address managerAddress, OperatorAttributes memory attr) internal {
        _getOperatorStateStorage(managerAddress).attr = attr;
    }

    /// @notice get operator's opt-in/opt-out state
    function _getOperatorOptInOutState(address managerAddress) internal view returns (OperatorOptInOutState memory) {
        return _getOperatorStateStorage(managerAddress).optInOutState;
    }

    function _setOperatorOptInOutState(address managerAddress, OperatorOptInOutState memory state) internal {
        _getOperatorStateStorage(managerAddress).optInOutState = state;
    }

    /// @notice get operator's keys range state
    function _getOperatorKeysRangeState(address managerAddress) internal view returns (OperatorKeysRangeState memory) {
        return _getOperatorStateStorage(managerAddress).keysRangeState;
    }

    function _setOperatorKeysRangeState(address managerAddress, OperatorKeysRangeState memory state) internal {
        _getOperatorStateStorage(managerAddress).keysRangeState = state;
    }

    /// @notice get operator's extra data
    function _getOperatorExtraData(address managerAddress) internal view returns (OperatorExtraData memory) {
        return _getOperatorStateStorage(managerAddress).extraData;
    }

    function _setOperatorExtraData(address managerAddress, OperatorExtraData memory data) internal {
        _getOperatorStateStorage(managerAddress).extraData = data;
    }

    /// @notice get manager address linked to the operator's reward address
    function _getOperatorManager(address rewardAddress) internal view returns (address managerAddress) {
        return _getOperatorsDataStorage()._managers[rewardAddress];
    }

    function _setOperatorManager(address rewardAddress, address managerAddress) internal {
        _getOperatorsDataStorage()._managers[rewardAddress] = managerAddress;
    }
}
