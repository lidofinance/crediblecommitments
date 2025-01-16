// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

enum StakingModuleStatus {
    Active, // deposits and rewards allowed
    DepositsPaused, // deposits NOT allowed, rewards allowed
    Stopped // deposits and rewards NOT allowed

}

interface IStakingModule {
    /// @notice Returns the type of the staking module
    function getType() external view returns (bytes32);
    function getNodeOperatorsCount() external view returns (uint256);
    function getNodeOperatorIsActive(uint256 nodeOperatorId) external view returns (bool);
}
