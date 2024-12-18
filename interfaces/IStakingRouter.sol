// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

struct StakingModule {
   /// @notice Unique id of the staking module.
   uint24 id;
   /// @notice Address of the staking module.
   address stakingModuleAddress;
   /// @notice Part of the fee taken from staking rewards that goes to the staking module.
   uint16 stakingModuleFee;
   /// @notice Part of the fee taken from staking rewards that goes to the treasury.
   uint16 treasuryFee;
   /// @notice Maximum stake share that can be allocated to a module, in BP.
   /// @dev Formerly known as `targetShare`.
   uint16 stakeShareLimit;
   /// @notice Staking module status if staking module can not accept the deposits or can
   /// participate in further reward distribution.
   uint8 status;
   /// @notice Name of the staking module.
   string name;
   /// @notice block.timestamp of the last deposit of the staking module.
   /// @dev NB: lastDepositAt gets updated even if the deposit value was 0 and no actual deposit happened.
   uint64 lastDepositAt;
   /// @notice block.number of the last deposit of the staking module.
   /// @dev NB: lastDepositBlock gets updated even if the deposit value was 0 and no actual deposit happened.
   uint256 lastDepositBlock;
   /// @notice Number of exited validators.
   uint256 exitedValidatorsCount;
   /// @notice Module's share threshold, upon crossing which, exits of validators from the module will be prioritized, in BP.
   uint16 priorityExitShareThreshold;
   /// @notice The maximum number of validators that can be deposited in a single block.
   /// @dev Must be harmonized with `OracleReportSanityChecker.appearedValidatorsPerDayLimit`.
   /// See docs for the `OracleReportSanityChecker.setAppearedValidatorsPerDayLimit` function.
   uint64 maxDepositsPerBlock;
   /// @notice The minimum distance between deposits in blocks.
   /// @dev Must be harmonized with `OracleReportSanityChecker.appearedValidatorsPerDayLimit`.
   /// See docs for the `OracleReportSanityChecker.setAppearedValidatorsPerDayLimit` function).
   uint64 minDepositBlockDistance;
}

interface IStakingRouter {
    function getStakingModule(
       uint256 stakingModuleId
    ) external view returns (StakingModule memory);
}
