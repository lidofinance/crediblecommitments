// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {IStakingModule} from "./IStakingModule.sol";

interface ICuratedModule is IStakingModule {
    function getNodeOperator(uint256 nodeOperatorId, bool fullInfo)
        external
        view
        returns (
            bool active,
            string memory name,
            address rewardAddress,
            uint64 totalVettedKeys,
            uint64 totalExitedKeys,
            uint64 totalAddedKeys
        );
}
