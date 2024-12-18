// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../interfaces/IStakingRouter.sol";

contract MockStakingRouter is IStakingRouter {
    struct MockStakingModule {
        uint24 id;
        address stakingModuleAddress;
        uint16 stakingModuleFee;
        uint16 treasuryFee;
        uint16 stakeShareLimit;
        uint8 status;
        string name;
        uint64 lastDepositAt;
        uint256 lastDepositBlock;
        uint256 exitedValidatorsCount;
        uint16 priorityExitShareThreshold;
        uint64 maxDepositsPerBlock;
        uint64 minDepositBlockDistance;
    }

    mapping(uint256 => MockStakingModule) public stakingModules;

    function setStakingModule(uint256 moduleId, MockStakingModule memory module) external {
        stakingModules[moduleId] = module;
    }

    function getStakingModule(uint256 moduleId) external view override returns (StakingModule memory) {
        MockStakingModule memory mockModule = stakingModules[moduleId];
        return StakingModule({
            id: mockModule.id,
            stakingModuleAddress: mockModule.stakingModuleAddress,
            stakingModuleFee: mockModule.stakingModuleFee,
            treasuryFee: mockModule.treasuryFee,
            stakeShareLimit: mockModule.stakeShareLimit,
            status: mockModule.status,
            name: mockModule.name,
            lastDepositAt: mockModule.lastDepositAt,
            lastDepositBlock: mockModule.lastDepositBlock,
            exitedValidatorsCount: mockModule.exitedValidatorsCount,
            priorityExitShareThreshold: mockModule.priorityExitShareThreshold,
            maxDepositsPerBlock: mockModule.maxDepositsPerBlock,
            minDepositBlockDistance: mockModule.minDepositBlockDistance
        });
    }
}
