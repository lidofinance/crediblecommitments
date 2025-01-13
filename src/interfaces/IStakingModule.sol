// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.24;

interface IStakingModule {
    function getNodeOperatorsCount() external view returns (uint256);
    function getNodeOperatorIsActive(uint256 nodeOperatorId) external view returns (bool);
}
