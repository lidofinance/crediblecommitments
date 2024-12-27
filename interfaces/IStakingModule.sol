// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

struct CSMNodeOperator {
   uint32 totalAddedKeys;
   uint32 totalWithdrawnKeys;
   uint32 totalDepositedKeys;
   uint32 totalVettedKeys;
   uint32 stuckValidatorsCount;
   uint32 depositableValidatorsCount;
   uint32 targetLimit;
   uint8 targetLimitMode;
   uint32 totalExitedKeys;
   uint32 enqueuedCount;
   address managerAddress;
   address proposedManagerAddress;
   address rewardAddress;
   address proposedRewardAddress;
   bool extendedManagerPermissions;
}

interface IStakingModule {
   function getNodeOperatorsCount() external view returns (uint256);
}

interface ICuratedModule {
   function getNodeOperator(
      uint256 nodeOperatorId,
      bool fullInfo
   ) external view returns (
      bool active,
      string memory name,
      address rewardAddress,
      uint64 totalVettedValidators,
      uint64 totalExitedValidators,
      uint64 totalAddedValidators
   );
}

interface ICSModule {
   function getNodeOperatorIsActive(
      uint256 nodeOperatorId
   ) external view returns (bool);

   function getNodeOperator(
      uint256 operatorId
   ) external view returns (CSMNodeOperator memory);
}
