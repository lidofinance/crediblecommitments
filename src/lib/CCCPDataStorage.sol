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
    OperatorKeysRangeState keysRangeState;
    // 3rd slot
    OperatorOptInOutState optInOutState;
    // 4+ slots
    OperatorExtraData extraData;
}

struct ModuleState {
    // is module disabled for pre-confs
    bool isDisabled;
    // hopefully, we won't need more than 2^64 validators
    uint64 maxValidators;
}

struct Config {
    // minimum duration of the opt-in period in blocks
    uint64 optInMinDurationBlocks;
    // delay in blocks before the operator can opt-in again after opt-out
    uint64 optOutDelayDurationBlocks;
    uint64 defaultModuleMaxValidators;
    uint64 defaultBlockGasLimit;
}

library CCCPDataStorage {
    struct CCCPData {
        Config _config;
        mapping(address => OperatorState) _operators;
        // operator's reward to manager address mapping, allow operators not use their reward address
        mapping(address => address) _managers;
        mapping(uint256 => ModuleState) _modules;
    }

    // keccak256(abi.encode(uint256(keccak256("lido.cccp.CCCPData")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant CCCP_DATA_LOCATION = 0x250c379b4df7db4aa0cebfe63c44e477918a4a35c66c19b68448ebd5517bd100;

    function _getStorage() internal pure returns (CCCPData storage $) {
        assembly {
            $.slot := CCCP_DATA_LOCATION
        }
    }

    function _getOperatorStateStorage(address managerAddress) private view returns (OperatorState storage) {
        return _getStorage()._operators[managerAddress];
    }

    /// @notice get operator' full state
    function _getOperatorState(address managerAddress) internal view returns (OperatorState memory) {
        return _getStorage()._operators[managerAddress];
    }

    // function _setOperatorState(address managerAddress, OperatorState memory state) internal {
    //     _getStorage()._operators[managerAddress] = operator;
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
        return _getStorage()._managers[rewardAddress];
    }

    function _setOperatorManager(address rewardAddress, address managerAddress) internal {
        _getStorage()._managers[rewardAddress] = managerAddress;
    }

    /// MODULES DATA

    function _getModuleState(uint24 moduleId) internal view returns (ModuleState memory) {
        return _getStorage()._modules[moduleId];
    }

    function _setModuleState(uint24 moduleId, ModuleState memory state) internal {
        _getStorage()._modules[moduleId] = state;
    }

    /// CONFIG DATA

    function _getConfigOptInOut() internal view returns (Config memory) {
        return _getStorage()._config;
    }

    // function _getConfigOptInOutVars() internal view returns (uint64 optInMinDurationBlocks, uint64 optOutDelayDurationBlocks) {
    //     Config memory optInOutCfg = _getConfigOptInOut();
    //     return (optInOutCfg.optInMinDurationBlocks, optInOutCfg.optOutDelayDurationBlocks);
    // }

    function _setConfigOptInOut(Config memory config) internal {
        _getStorage()._config = config;
    }

    // function _setConfigOptInOutVars(uint64 optInMinDurationBlocks, uint64 optOutDelayDurationBlocks) internal {
    //     _setConfigOptInOut(
    //         Config({optInMinDurationBlocks: optInMinDurationBlocks, optOutDelayDurationBlocks: optOutDelayDurationBlocks})
    //     );
    // }
}
