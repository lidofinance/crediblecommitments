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
        uint64 keyIndexStart,
        uint64 keyIndexEnd,
        string calldata rpcURL
    ) external;
    function optOut() external;
    function updateKeysRange(uint64 keyIndexStart, uint64 keyIndexEnd) external;
    function updateManager(uint24 moduleId, uint64 operatorId, address newManager) external;

    function getOperator(address manager)
        external
        view
        returns (uint24 moduleId, uint64 operatorId, bool isEnabled, OperatorState memory state);

    function getOperator(uint24 _moduleId, uint64 _operatorId)
        external
        view
        returns (uint24 moduleId, uint64 operatorId, bool isEnabled, OperatorState memory state);
    function getModuleBlockGasLimit(uint24 moduleId) external view returns (uint64);
    function getModuleOperatorMaxValidators(uint24 moduleId) external view returns (uint64);
    function getOperatorManager(uint24 moduleId, uint64 operatorId) external view returns (address);
    function getOperatorIsEnabledForPreconf(uint24 moduleId, uint64 operatorId) external view returns (bool);
    function getOperatorAllowedValidators(uint24 moduleId, uint64 operatorId) external view returns (uint64);
}
