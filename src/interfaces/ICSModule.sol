// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {IStakingModule} from "./IStakingModule.sol";

struct CSMNodeOperator {
    uint32 totalAddedKeys;
    uint32 totalWithdrawnKeys;
    uint32 totalDepositedKeys;
    uint32 totalVettedKeys;
    uint32 stuckKeysCount;
    uint32 depositableKeysCount;
    uint32 targetLimit;
    uint8 targetLimitMode;
    uint32 totalExitedKeys;
    uint32 enqueuedCount;
    address managerAddress;
    address proposedManagerAddress;
    address rewardAddress;
    address proposedRewardAddress;
    bool extendedManagerPermissions;
}

interface ICSModule is IStakingModule {
    function getNodeOperator(uint256 operatorId) external view returns (CSMNodeOperator memory);
}
