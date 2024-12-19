// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IStakingModule {
   function getNodeOperatorsCount() external view returns (uint256);

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
