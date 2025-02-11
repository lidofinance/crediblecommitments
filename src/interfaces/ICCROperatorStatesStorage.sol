// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

/**
 * @title IOperatorStatesStorage
 * @notice Interface for interacting with the storage and control states of operators.
 */
interface ICCROperatorStatesStorage {
    /// @notice operator optin/optout state
    /// operator can be in several statuses:
    // 1. new, not registered: optInBlock = 0, optOutBlock = 0
    // 2. registered: optInBlock > 0, optOutBlock = 0
    // 3. opt-out in progress: optInBlock > 0, optOutBlock > 0, optOutBlock + optOutDelayBlocksDelay >= block.number
    // 4. forded opt-out in progress: optInBlock > 0, optOutBlock > 0, isBlocked = true, optOutBlock + optOutDelayBlocksDelay >= block.number
    // 5. opt-out completed: optInBlock > 0, optOutBlock > 0, isBlocked = false, optOutBlock + optOutDelayBlocksDelay < block.number
    // 6. forced opt-out completed: optInBlock > 0, optOutBlock > 0, isBlocked = true, optOutBlock + optOutDelayBlocksDelay < block.number

    // If isBlocked is set, optOutBlock has non-zero value of the block number when the operator was forced to opt out.
    // If operator has "forced opt-out completed" status, it can't opt in again until the committee decides to allow it (clear isBlocked flag).
    struct OptInOutState {
        uint64 optInBlock;
        uint64 optOutBlock;
        uint64 optInDelayOffBlock;
        uint64 optOutDelayOffBlock;
    }

    struct KeyRange {
        uint64 indexStart;
        uint64 indexEnd;
    }

    struct ExtraData {
        string rpcURL;
    }

    struct Delegate {
        bytes key;
    }

    struct Commitment {
        bytes32 id; // reserved for future use
        KeyRange keyRange;
        ExtraData extraData;
    }

    struct OperatorStateOld {
        address manager;
        KeyRange keyRange;
        OptInOutState optInOutState;
        ExtraData extraData;
    }

    struct OperatorState {
        bool isBlocked; // if the operator is blocked (i.e. forced to opt out by the committee)
        address manager;
        OptInOutState optInOutState;
        Commitment[] commitments;
        Delegate[] delegates;
    }

    /**
     * @notice Storage structure for operator states data.
     * @dev
     * @param _operators Mapping opKey (module id + operator id) to operator state
     * @param _managers Mapping manager address to opKey
     */
    struct OperatorsStatesStorage {
        mapping(uint256 => OperatorState) _operators;
        mapping(address => uint256) _managers;
    }

    error ManagerBelongsToOtherOperator();
    error OperatorNotRegistered();
    error ManagerNotRegistered();
    error IndexOutOfRange();
}
