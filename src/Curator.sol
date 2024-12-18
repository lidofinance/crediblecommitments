// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IStakingRouter, StakingModule} from "../interfaces/IStakingRouter.sol";

contract Curator {
    event Succeeded(
        address sender,
        address rewardAddress,
        address eoa,
        uint256 moduleId,
        uint256 operatorId,
        uint256 keysRangeStart,
        uint256 keysRangeEnd
    );

    event Failed(
        address sender,
        address rewardAddress,
        address eoa,
        uint256 moduleId,
        uint256 operatorId,
        uint256 keysRangeStart,
        uint256 keysRangeEnd
    );

    event Test(
        uint24 id,
        address stakingModuleAddress,
        uint16 stakingModuleFee,
        uint16 treasuryFee,
        uint16 stakeShareLimit,
        uint8 status,
        string name,
        uint64 lastDepositAt,
        uint256 lastDepositBlock,
        uint256 exitedValidatorsCount,
        uint16 priorityExitShareThreshold,
        uint64 maxDepositsPerBlock,
        uint64 minDepositBlockDistance
    );

    struct RegisteredOperator {
        address eoa;
        uint256 moduleId;
        uint256 operatorId;
        uint256 keysRangeStart;
        uint256 keysRangeEnd;
    }

    address immutable public stakingRouterAddress;
    address public owner;

    mapping(address => RegisteredOperator) public operators;

    // Лимит валидаторов для каждого Staking Module
    mapping(uint256 => uint256) public maxValidatorsForModule;

    // Модификатор для проверки прав владельца
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(address _stakingRouterAddress) {
        stakingRouterAddress = _stakingRouterAddress;
        owner = msg.sender;
    }

    function optIn(
        address rewardAddress,
        address eoa,
        uint256 moduleId,
        uint256 operatorId,
        uint256 keysRangeStart,
        uint256 keysRangeEnd
    ) public {
        IStakingRouter router = IStakingRouter(payable(stakingRouterAddress));

        StakingModule memory module = router.getStakingModule(moduleId);

        // Проверяем, не превышает ли количество ключей лимит для модуля
        uint256 totalKeys = keysRangeEnd - keysRangeStart + 1;
        require(
            totalKeys <= maxValidatorsForModule[moduleId],
            "Validator limit exceeded for module"
        );

        operators[rewardAddress] = RegisteredOperator({
            eoa: eoa,
            moduleId: moduleId,
            operatorId: operatorId,
            keysRangeStart: keysRangeStart,
            keysRangeEnd: keysRangeEnd
        });

        emit Test(
            module.id,
            module.stakingModuleAddress,
            module.stakingModuleFee,
            module.treasuryFee,
            module.stakeShareLimit,
            module.status,
            module.name,
            module.lastDepositAt,
            module.lastDepositBlock,
            module.exitedValidatorsCount,
            module.priorityExitShareThreshold,
            module.maxDepositsPerBlock,
            module.minDepositBlockDistance
        );

        /// emit Succeeded(msg.sender, msg.sender, eoa, moduleId, operatorId, keysRangeStart, keysRangeEnd);
    }

    // Установка лимита валидаторов для модуля (только для владельца)
    function setMaxValidatorsForStakingModule(uint256 moduleId, uint256 maxValidators) external onlyOwner {
        require(moduleId > 0, "Invalid module ID");
        require(maxValidators > 0, "Max validators must be greater than 0");

        maxValidatorsForModule[moduleId] = maxValidators;
    }

    // Изменение владельца
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        owner = newOwner;
    }
}
