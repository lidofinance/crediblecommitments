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

struct OperatorExtraData {
    string rpcURL;
}

struct OperatorState {
    address manager;
    OperatorKeysRangeState keysRangeState;
    OperatorOptInOutState optInOutState;
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
    uint64 defaultOperatorMaxValidators; //todo rename to per op
    uint64 defaultBlockGasLimit;
}

library CCCPDataStorage {
    struct CCCPData {
        // opKey (module id + operator id) => operator state
        mapping(uint256 => OperatorState) _operators;
        // manager address to opKey
        mapping(address => uint256) _managers;
        // modules state
        mapping(uint256 => ModuleState) _modules;
        // config
        Config _config;
    }

    // keccak256(abi.encode(uint256(keccak256("lido.cccp.CCCPData")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant CCCP_DATA_LOCATION = 0x250c379b4df7db4aa0cebfe63c44e477918a4a35c66c19b68448ebd5517bd100;

    error ManagerBelongsToOtherOperator();

    function _getStorage() private pure returns (CCCPData storage $) {
        assembly {
            $.slot := CCCP_DATA_LOCATION
        }
    }

    function _getOperatorStateStorage(uint256 opKey) private view returns (OperatorState storage) {
        return _getStorage()._operators[opKey];
    }

    /// @notice get operator' full state
    function _getOperatorState(uint256 opKey) internal view returns (OperatorState memory) {
        return _getOperatorStateStorage(opKey);
    }

    /// @notice get operator's opt-in/opt-out state
    function _getOperatorOptInOutState(uint256 opKey) internal view returns (OperatorOptInOutState memory) {
        return _getOperatorStateStorage(opKey).optInOutState;
    }

    function _setOperatorOptInOutState(uint256 opKey, OperatorOptInOutState memory state) internal {
        _getOperatorStateStorage(opKey).optInOutState = state;
    }

    /// @notice get operator's keys range state
    function _getOperatorKeysRangeState(uint256 opKey) internal view returns (OperatorKeysRangeState memory) {
        return _getOperatorStateStorage(opKey).keysRangeState;
    }

    function _setOperatorKeysRangeState(uint256 opKey, OperatorKeysRangeState memory state) internal {
        _getOperatorStateStorage(opKey).keysRangeState = state;
    }

    /// @notice get operator's extra data
    function _getOperatorExtraData(uint256 opKey) internal view returns (OperatorExtraData memory) {
        return _getOperatorStateStorage(opKey).extraData;
    }

    function _setOperatorExtraData(uint256 opKey, OperatorExtraData memory data) internal {
        _getOperatorStateStorage(opKey).extraData = data;
    }

    /// @notice get manager address linked to the operator's reward address
    function _getOperatorManager(uint256 opKey) internal view returns (address managerAddress) {
        return _getOperatorStateStorage(opKey).manager;
    }

    /// @dev safe manager address update
    function _setOperatorManager(uint256 opKey, address manager) internal {
        _checkManager(opKey, manager);
        OperatorState storage $ = _getOperatorStateStorage(opKey);

        address oldManager = $.manager;
        if (oldManager != address(0) && oldManager != manager) {
            delete _getStorage()._managers[oldManager];
        }
        $.manager = manager;
        _getStorage()._managers[manager] = opKey;
    }

    function _getManagerOpKey(address manager) internal view returns (uint256) {
        return _getStorage()._managers[manager];
    }

    function _checkManager(uint256 opKey, address manager) internal view {
        uint256 managerOpKey = _getManagerOpKey(manager);
        // revert if the manager address is linked to the other operator
        if (managerOpKey != 0 && managerOpKey != opKey) {
            revert ManagerBelongsToOtherOperator();
        }
    }

    function __encOpKey(uint24 moduleId, uint64 operatorId) internal pure returns (uint256) {
        return uint256(moduleId) << 64 | operatorId;
    }

    function __decOpKey(uint256 opKey) internal pure returns (uint24 moduleId, uint64 operatorId) {
        return (uint24(opKey >> 64), uint64(opKey));
    }

    /// MODULES DATA

    function _getModuleState(uint24 moduleId) internal view returns (ModuleState memory) {
        return _getStorage()._modules[moduleId];
    }

    function _setModuleState(uint24 moduleId, ModuleState memory state) internal {
        _getStorage()._modules[moduleId] = state;
    }

    /// CONFIG DATA

    function _getConfig() internal view returns (Config memory) {
        return _getStorage()._config;
    }

    function _setConfig(Config memory config) internal {
        _getStorage()._config = config;
    }
}
