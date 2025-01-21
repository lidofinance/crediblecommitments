// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {ICuratedModule} from "../../../src/interfaces/ICuratedModule.sol";
import {StakingModuleMock} from "./StakingModuleMock.sol";

contract CuratedModuleMock is StakingModuleMock, ICuratedModule {
    function getNodeOperator(uint256 id, bool)
        public
        view
        virtual
        returns (
            bool active,
            string memory name,
            address rewardAddress,
            uint64 totalVettedValidators,
            uint64 totalExitedValidators,
            uint64 totalAddedValidators
        )
    {
        active = ops[id].active;
        rewardAddress = ops[id].rewardAddress;
        totalAddedValidators = ops[id].totalAddedValidators;

        // silence warnings
        name;
        totalExitedValidators;
        totalVettedValidators;
    }

    function getType() external pure returns (bytes32 moduleType) {
        moduleType = "curated-onchain-v1";
    }
}
