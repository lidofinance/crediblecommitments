// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {ICSModule, CSMNodeOperator} from "../../../src/interfaces/ICSModule.sol";
import {StakingModuleMock} from "./StakingModuleMock.sol";

contract CSModuleMock is StakingModuleMock, ICSModule {
    function getNodeOperator(uint256 id) public view returns (CSMNodeOperator memory no) {
        no.totalAddedKeys = ops[id].totalAddedKeys;
        no.rewardAddress = ops[id].rewardAddress;
    }

    function getType() external pure returns (bytes32 moduleType) {
        moduleType = "community-onchain-v1";
    }
}
