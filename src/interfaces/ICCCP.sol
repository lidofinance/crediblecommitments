// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {ICCCPOperatorStatesStorage} from "./ICCCPOperatorStatesStorage.sol";

/**
 * @title ICCCP
 * @notice Interface for CredibleCommitmentCurationProvider.
 */
interface ICCCP is ICCCPOperatorStatesStorage {
    function optIn(
        uint24 moduleId,
        uint64 operatorId,
        address manager,
        uint64 newKeyIndexRangeStart,
        uint64 newKeyIndexRangeEnd,
        string calldata rpcURL
    ) external;
    function optOut() external;
    function updateKeysRange(uint64 newKeyIndexRangeStart, uint64 newKeyIndexRangeEnd) external;
    function updateManager(uint24 moduleId, uint64 operatorId, address newManager) external;

    function getOperator(address manager)
        external
        view
        returns (uint24 moduleId, uint64 operatorId, bool isEnabled, OperatorState memory state);

    function getOperator(uint24 _moduleId, uint64 _operatorId)
        external
        view
        returns (uint24 moduleId, uint64 operatorId, bool isEnabled, OperatorState memory state);
}
