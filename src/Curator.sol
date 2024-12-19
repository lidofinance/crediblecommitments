// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IStakingRouter, StakingModule} from "../interfaces/IStakingRouter.sol";
import {IStakingModule} from "../interfaces/IStakingModule.sol";

contract Curator {
    event Succeeded(
       address sender,
       address rewardAddress,
       address proxyKey,
       uint256 moduleId,
       uint256 operatorId,
       uint256 keysRangeStart,
       uint256 keysRangeEnd
    );

    error ModuleIdCheckFailed(
       address sender,
       uint256 moduleId,
       uint256 totalModulesCount
    );

    error OperatorIdCheckFailed(
       address sender,
       uint256 moduleId,
       uint256 operatorId,
       uint256 totalOperatorsCount
    );

    error OperatorNotActive(
       address sender,
       uint256 operatorId
    );

    error OperatorAlreadyRegistered(
       address sender,
       address operatorRewardAddress,
       uint256 moduleId,
       uint256 operatorId
    );

    error RewardAddressMismatch(
       address sender,
       uint256 operatorId,
       address operatorRewardAddress
    );

    error KeysIndexMismatch(
       address sender,
       uint256 moduleId,
       uint256 operatorId,
       uint256 keysRangeStart,
       uint256 keysRangeEnd,
       uint64 totalExitedValidators,
       uint64 totalAddedValidators
    );

    struct RegisteredOperator {
       address proxyKey;
       uint256 moduleId;
       uint256 operatorId;
       uint256 keysRangeStart;
       uint256 keysRangeEnd;
    }

    address immutable public stakingRouterAddress;

    mapping(address => RegisteredOperator) public operators;

    constructor(address _stakingRouterAddress) {
       stakingRouterAddress = _stakingRouterAddress;
    }

    function optIn(
       address proxyKey,
       uint256 moduleId,
       uint256 operatorId,
       uint256 keysRangeStart,
       uint256 keysRangeEnd
    ) public {
       IStakingRouter router = IStakingRouter(payable(stakingRouterAddress));

       uint256 modulesCount = router.getStakingModulesCount();

       if (moduleId < 1 || moduleId > modulesCount) {
          revert ModuleIdCheckFailed(msg.sender, moduleId, modulesCount);
       }

       address moduleAddress = router.getStakingModule(moduleId).stakingModuleAddress;

       IStakingModule module = IStakingModule(moduleAddress);

       uint256 nodeOperatorsCount = module.getNodeOperatorsCount();

       if (operatorId > nodeOperatorsCount) {
          revert OperatorIdCheckFailed(msg.sender, moduleId, operatorId, nodeOperatorsCount);
       }

       address operatorRewardAddress = _checkOperatorAndGetRewardAddress(
          module,
          moduleId,
          operatorId,
          keysRangeStart,
          keysRangeEnd
       );

       // @todo Uncomment when we create test node operator in 3rd module
       /*if (msg.sender != operatorRewardAddress) {
          revert RewardAddressMismatch(msg.sender, operatorId, operatorRewardAddress);
       }*/

       if (operators[operatorRewardAddress].moduleId != 0 && operators[operatorRewardAddress].operatorId != 0) {
          revert OperatorAlreadyRegistered(msg.sender, operatorRewardAddress, moduleId, operatorId);
       }

       operators[operatorRewardAddress] = RegisteredOperator({
          proxyKey: proxyKey,
          moduleId: moduleId,
          operatorId: operatorId,
          keysRangeStart: keysRangeStart,
          keysRangeEnd: keysRangeEnd
       });

       emit Succeeded(msg.sender, operatorRewardAddress, proxyKey, moduleId, operatorId, keysRangeStart, keysRangeEnd);
    }

    function _checkOperatorAndGetRewardAddress(
       IStakingModule module,
       uint256 moduleId,
       uint256 operatorId,
       uint256 keysRangeStart,
       uint256 keysRangeEnd
    ) internal returns (address operatorRewardAddress) {
       (
          bool isOperatorActive,
          string memory operatorName,
          address rewardAddress,
          uint64 totalVettedValidators,
          uint64 totalExitedValidators,
          uint64 totalAddedValidators
       ) = module.getNodeOperator(operatorId, true);

       if (!isOperatorActive) {
          revert OperatorNotActive(msg.sender, operatorId);
       }

       if (
          totalExitedValidators > keysRangeStart ||
          totalAddedValidators < keysRangeEnd ||
          keysRangeEnd < keysRangeStart
       ) {
          revert KeysIndexMismatch(
             msg.sender,
             moduleId,
             operatorId,
             keysRangeStart,
             keysRangeEnd,
             totalExitedValidators,
             totalAddedValidators
          );
       }

       operatorRewardAddress = rewardAddress;
    }
}
