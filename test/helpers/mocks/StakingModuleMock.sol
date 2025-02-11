// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {IStakingModule} from "../../../src/interfaces/IStakingModule.sol";

abstract contract StakingModuleMock is IStakingModule {
    struct NO {
        bool active;
        address rewardAddress;
        uint32 totalAddedKeys;
    }

    NO[] public ops;

    function addNo(bool active, address rewAddr, uint32 keys) public {
        uint256 id = ops.length;
        ops.push();
        updNo(id, active, rewAddr, keys);
    }

    function updNo(uint256 id, bool active, address rewAddr, uint32 keys) public {
        ops[id].active = active;
        ops[id].rewardAddress = rewAddr;
        ops[id].totalAddedKeys = keys;
    }

    function updNoKeys(uint256 id, uint32 keys) public {
        ops[id].totalAddedKeys = keys;
    }

    function updNoActive(uint256 id, bool active) public {
        ops[id].active = active;
    }

    function updNoRewAddr(uint256 id, address rewAddr) public {
        ops[id].rewardAddress = rewAddr;
    }

    function getNodeOperatorsCount() external view returns (uint256) {
        return ops.length;
    }

    function getNodeOperatorIsActive(uint256 id) external view returns (bool) {
        return ops[id].active;
    }
}
