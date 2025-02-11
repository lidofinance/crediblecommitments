// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {ICCROperatorStatesStorage} from "./ICCROperatorStatesStorage.sol";

/**
 * @title ICCR
 * @notice Interface for CredibleCommitmentCurationProvider.
 */
interface ICCR is ICCROperatorStatesStorage {
    function optIn(
        uint24 moduleId,
        uint64 operatorId,
        address manager,
        uint64 keyIndexStart,
        uint64 keyIndexEnd,
        string calldata rpcURL
    ) external;
    function optOut() external;
    // function updateKeyRange(uint64 keyIndexStart, uint64 keyIndexEnd) external;
    // function updateManager(uint24 moduleId, uint64 operatorId, address newManager) external;

    function getOperatorManager(uint24 moduleId, uint64 operatorId) external view returns (address);
    function getOperatorDelegates(uint24 moduleId, uint64 operatorId) external view returns (Delegate[] memory);
    function getOperatorCommitments(uint24 moduleId, uint64 operatorId) external view returns (Commitment[] memory);

    function getOperator(uint24 moduleId, uint64 operatorId)
        external
        view
        returns (address manager, bool isBlocked, bool isEnabled, OptInOutState memory optInOutState);
    function getModuleBlockGasLimit(uint24 moduleId) external view returns (uint64);
    function getModuleOperatorMaxKeys(uint24 moduleId) external view returns (uint64);
    function getOperatorIsEnabledForPreconf(uint24 moduleId, uint64 operatorId) external view returns (bool);
    function getOperatorAllowedKeys(uint24 moduleId, uint64 operatorId) external view returns (uint64);
}
