// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {IStakingRouter, StakingModule} from "../../../src/interfaces/IStakingRouter.sol";

contract StakingRouterMock is IStakingRouter {
    struct SM {
        uint24 id;
        address addr;
    }

    SM[] public mods;

    constructor() {
        mods.push();
    }

    function addModule(address addr) public {
        uint24 id = uint24(mods.length);
        mods.push();
        updModule(id, addr);
    }

    function updModule(uint24 id, address addr) public {
        require(id > 0);
        mods[id].id = id;
        mods[id].addr = addr;
    }

    function getStakingModulesCount() external view returns (uint256) {
        return mods.length - 1;
    }

    function getStakingModule(uint256 id) external view returns (StakingModule memory sm) {
        if (id == 0 || id >= mods.length) {
            revert StakingModuleUnregistered();
        }
        sm.id = mods[id].id;
        sm.stakingModuleAddress = mods[id].addr;
    }
}
