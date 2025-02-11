// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

struct StakingModule {
    uint24 id;
    address stakingModuleAddress;
    uint16 stakingModuleFee;
    uint16 treasuryFee;
    uint16 stakeShareLimit;
    uint8 status;
    string name;
    uint64 lastDepositAt;
    uint256 lastDepositBlock;
    uint256 exitedKeysCount;
    uint16 priorityExitShareThreshold;
    uint64 maxDepositsPerBlock;
    uint64 minDepositBlockDistance;
}

interface IStakingRouter {
    error StakingModuleUnregistered();

    function getStakingModulesCount() external view returns (uint256);
    function getStakingModule(uint256 stakingModuleId) external view returns (StakingModule memory);
}
