// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {IStakingRouter, StakingModule} from "../../src/interfaces/IStakingRouter.sol";

contract StakingRouterMock is IStakingRouter {
    struct SM {
        uint24 id;
        address addr;
        uint8 status;
    }

    SM[] public mods;

    constructor() {
        mods.push();
    }

    function addModule(address addr, uint8 status) public {
        uint24 id = uint24(mods.length);
        mods.push();
        updModule(id, addr, status);
    }

    function updModule(uint24 id, address addr, uint8 status) public {
        require(id > 0);
        mods[id].id = id;
        mods[id].addr = addr;
        mods[id].status = status;
    }

    function getStakingModulesCount() external view returns (uint256) {
        return mods.length - 1;
    }

    function getStakingModule(uint256 id) external view returns (StakingModule memory sm) {
        require(id > 0);
        sm.id = mods[id].id;
        sm.stakingModuleAddress = mods[id].addr;
        sm.status = mods[id].status;
    }
}
