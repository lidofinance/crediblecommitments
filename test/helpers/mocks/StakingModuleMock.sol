// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {IStakingModule} from "../../../src/interfaces/IStakingModule.sol";

abstract contract StakingModuleMock is IStakingModule {
    struct NO {
        bool active;
        address rewardAddress;
        uint32 totalAddedValidators;
    }

    NO[] public ops;

    function addNo(bool active, address rewAddr, uint32 total) public {
        uint256 id = ops.length;
        ops.push();
        updNo(id, active, rewAddr, total);
    }

    function updNo(uint256 id, bool active, address rewAddr, uint32 total) public {
        ops[id].active = active;
        ops[id].rewardAddress = rewAddr;
        ops[id].totalAddedValidators = total;
    }

    function getNodeOperatorsCount() external view returns (uint256) {
        return ops.length;
    }

    function getNodeOperatorIsActive(uint256 id) external view returns (bool) {
        return ops[id].active;
    }
}
