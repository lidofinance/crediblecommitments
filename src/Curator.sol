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

    mapping (address => RegisteredOperator) public operators;

    constructor(address _stakingRouterAddress) {
       stakingRouterAddress = _stakingRouterAddress;
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

       ///emit Succeeded(msg.sender, msg.sender, eoa, moduleId, operatorId, keysRangeStart, keysRangeEnd);
    }
}
