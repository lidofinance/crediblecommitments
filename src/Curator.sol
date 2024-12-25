// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IStakingRouter, StakingModule} from "../interfaces/IStakingRouter.sol";
import {IStakingModule} from "../interfaces/IStakingModule.sol";

contract Curator {
    event OptInSucceeded(
        address rewardAddress,
        address optInAddress,
        string rpcURL,
        uint256 moduleId,
        uint256 operatorId,
        uint256 keysRangeStart,
        uint256 keysRangeEnd
    );

    error ModuleIdCheckFailed(uint256 moduleId, uint256 totalModulesCount);

    error OperatorIdCheckFailed(uint256 moduleId, uint256 operatorId, uint256 totalOperatorsCount);

    error OperatorNotActive(uint256 moduleId, uint256 operatorId);

    error OperatorAlreadyRegistered(uint256 moduleId, uint256 operatorId);

    error OperatorNotRegistered(uint256 moduleId, uint256 operatorId, address operatorRewardAddress);

    error RewardAddressMismatch(address sender, uint256 operatorId, address operatorRewardAddress);

    error KeysIndexMismatch(
        uint256 moduleId,
        uint256 operatorId,
        uint256 keysRangeStart,
        uint256 keysRangeEnd,
        uint64 totalExitedValidators,
        uint64 totalAddedValidators
    );

    struct RegisteredOperator {
        bool isActive;
        address optInAddress;
        string rpcURL;
        uint256 moduleId;
        uint256 operatorId;
        uint256 keysRangeStart;
        uint256 keysRangeEnd;
    }

    uint256 public constant DEFAULT_MAX_VALIDATORS = 1000; // Default max validators if not set explicitly

    address public immutable stakingRouterAddress;
    address public immutable managerAddress;

    mapping(address => RegisteredOperator) public operators;
    mapping(uint256 => uint256) public maxValidatorsForModule;

    modifier onlyOwner() {
        require(msg.sender == managerAddress, "Not the owner");
        _;
    }

    constructor(address _stakingRouterAddress, address _managerAddress) {
        stakingRouterAddress = _stakingRouterAddress;
        managerAddress = _managerAddress;
    }

    function optIn(address optInAddress, string memory rpcURL, uint256 moduleId, uint256 operatorId, uint256 keysRangeStart, uint256 keysRangeEnd)
        public
    {
        IStakingRouter router = IStakingRouter(payable(stakingRouterAddress));

        _checkModuleId(router, moduleId);

        address moduleAddress = router.getStakingModule(moduleId).stakingModuleAddress;

        IStakingModule module = IStakingModule(moduleAddress);

        _checkOperatorId(module, moduleId, operatorId);

        address operatorRewardAddress =
            _checkOperatorAndGetRewardAddress(module, moduleId, operatorId, keysRangeStart, keysRangeEnd);

        _checkMaxValidators(moduleId, keysRangeStart, keysRangeEnd);

        if (msg.sender != operatorRewardAddress) {
          revert RewardAddressMismatch(msg.sender, operatorId, operatorRewardAddress);
        }

        if (operators[operatorRewardAddress].isActive) {
            revert OperatorAlreadyRegistered(moduleId, operatorId);
        }

        operators[operatorRewardAddress] = RegisteredOperator({
            isActive: true,
            optInAddress: optInAddress,
            rpcURL: rpcURL,
            moduleId: moduleId,
            operatorId: operatorId,
            keysRangeStart: keysRangeStart,
            keysRangeEnd: keysRangeEnd
        });

        emit OptInSucceeded(operatorRewardAddress, optInAddress, rpcURL, moduleId, operatorId, keysRangeStart, keysRangeEnd);
    }

    function optOut(uint256 moduleId, uint256 operatorId) public {
        IStakingRouter router = IStakingRouter(payable(stakingRouterAddress));

        _checkModuleId(router, moduleId);

        address moduleAddress = router.getStakingModule(moduleId).stakingModuleAddress;

        IStakingModule module = IStakingModule(moduleAddress);

        _checkOperatorId(module, moduleId, operatorId);

        address operatorRewardAddress = _getOperatorRewardAddress(module, operatorId);

        if (msg.sender != operatorRewardAddress && msg.sender != managerAddress) {
            revert RewardAddressMismatch(msg.sender, operatorId, operatorRewardAddress);
        }

        if (!operators[operatorRewardAddress].isActive) {
            revert OperatorNotRegistered(moduleId, operatorId, operatorRewardAddress);
        }

        operators[operatorRewardAddress].isActive = false;
    }

    function updateKeysRange(uint256 moduleId, uint256 operatorId, uint256 newKeysRangeStart, uint256 newKeysRangeEnd)
        public
    {
        IStakingRouter router = IStakingRouter(payable(stakingRouterAddress));

        _checkModuleId(router, moduleId);

        address moduleAddress = router.getStakingModule(moduleId).stakingModuleAddress;

        IStakingModule module = IStakingModule(moduleAddress);

        _checkOperatorId(module, moduleId, operatorId);

        _checkMaxValidators(moduleId, newKeysRangeStart, newKeysRangeEnd);

        address operatorRewardAddress =
            _checkOperatorAndGetRewardAddress(module, moduleId, operatorId, newKeysRangeStart, newKeysRangeEnd);

        if (msg.sender != operatorRewardAddress) {
            revert RewardAddressMismatch(msg.sender, operatorId, operatorRewardAddress);
        }

        if (!operators[operatorRewardAddress].isActive) {
            revert OperatorNotRegistered(moduleId, operatorId, operatorRewardAddress);
        }

        operators[operatorRewardAddress].keysRangeStart = newKeysRangeStart;
        operators[operatorRewardAddress].keysRangeEnd = newKeysRangeEnd;
    }

    function getOperator(address rewardAddress) public view returns (
        bool isActive,
        address optInAddress,
        string memory rpcURL,
        uint256 moduleId,
        uint256 operatorId,
        uint256 keysRangeStart,
        uint256 keysRangeEnd
    ) {
        RegisteredOperator memory operator = operators[rewardAddress];

        return (
            operator.isActive,
            operator.optInAddress,
            operator.rpcURL,
            operator.moduleId,
            operator.operatorId,
            operator.keysRangeStart,
            operator.keysRangeEnd
        );
    }

    function setMaxValidatorsForStakingModule(uint256 moduleId, uint256 maxValidators) external onlyOwner {
        require(moduleId > 0, "Invalid module ID");
        require(maxValidators > 0, "Max validators must be greater than 0");

        maxValidatorsForModule[moduleId] = maxValidators;
    }

    function _checkMaxValidators(uint256 moduleId, uint256 keysRangeStart, uint256 keysRangeEnd) internal {
        uint256 totalKeys = keysRangeEnd - keysRangeStart + 1;
        uint256 maxValidators =
            maxValidatorsForModule[moduleId] == 0 ? DEFAULT_MAX_VALIDATORS : maxValidatorsForModule[moduleId];

        require(totalKeys <= maxValidators, "Validator limit exceeded for module");
    }

    function _checkModuleId(IStakingRouter router, uint256 moduleId) internal {
        uint256 modulesCount = router.getStakingModulesCount();

        if (moduleId < 1 || moduleId > modulesCount) {
            revert ModuleIdCheckFailed(moduleId, modulesCount);
        }
    }

    function _checkOperatorId(IStakingModule module, uint256 moduleId, uint256 operatorId) internal {
        uint256 nodeOperatorsCount = module.getNodeOperatorsCount();

        if (operatorId > nodeOperatorsCount) {
            revert OperatorIdCheckFailed(moduleId, operatorId, nodeOperatorsCount);
        }
    }

    function _getOperatorRewardAddress(IStakingModule module, uint256 operatorId)
        internal
        view
        returns (address operatorRewardAddress)
    {
        (
            bool isOperatorActive,
            string memory operatorName,
            address rewardAddress,
            uint64 totalVettedValidators,
            uint64 totalExitedValidators,
            uint64 totalAddedValidators
        ) = module.getNodeOperator(operatorId, true);

        operatorRewardAddress = rewardAddress;
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
            revert OperatorNotActive(moduleId, operatorId);
        }

        if (
            totalExitedValidators > keysRangeStart || totalAddedValidators < keysRangeEnd
                || keysRangeEnd < keysRangeStart
        ) {
            revert KeysIndexMismatch(
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
