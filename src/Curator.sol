// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IStakingRouter, StakingModule} from "../interfaces/IStakingRouter.sol";
import {CSMNodeOperator, IStakingModule, ICuratedModule, ICSModule} from "../interfaces/IStakingModule.sol";

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
        _checkOperatorData(moduleAddress, moduleId, operatorId, keysRangeStart, keysRangeEnd);
        _checkMaxValidators(moduleId, keysRangeStart, keysRangeEnd);

        address operatorRewardAddress = _getOperatorRewardAddress(moduleAddress, moduleId, operatorId);

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

        address operatorRewardAddress = _getOperatorRewardAddress(moduleAddress, moduleId, operatorId);

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
        _checkOperatorData(moduleAddress, moduleId, operatorId, newKeysRangeStart, newKeysRangeEnd);
        _checkMaxValidators(moduleId, newKeysRangeStart, newKeysRangeEnd);

        address operatorRewardAddress = _getOperatorRewardAddress(moduleAddress, moduleId, operatorId);

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

    function _checkMaxValidators(uint256 moduleId, uint256 keysRangeStart, uint256 keysRangeEnd) internal view {
        uint256 totalKeys = keysRangeEnd - keysRangeStart + 1;
        uint256 maxValidators =
            maxValidatorsForModule[moduleId] == 0 ? DEFAULT_MAX_VALIDATORS : maxValidatorsForModule[moduleId];

        require(totalKeys <= maxValidators, "Validator limit exceeded for module");
    }

    function _checkModuleId(IStakingRouter router, uint256 moduleId) internal view {
        uint256 modulesCount = router.getStakingModulesCount();

        if (moduleId < 1 || moduleId > modulesCount) {
            revert ModuleIdCheckFailed(moduleId, modulesCount);
        }
    }

    function _checkOperatorId(IStakingModule module, uint256 moduleId, uint256 operatorId) internal view {
        uint256 nodeOperatorsCount = module.getNodeOperatorsCount();

        if (operatorId >= nodeOperatorsCount) {
            revert OperatorIdCheckFailed(moduleId, operatorId, nodeOperatorsCount);
        }
    }

    function _getOperatorData(address moduleAddress, uint256 moduleId, uint256 operatorId) internal view returns (
        bool isOperatorActive,
        address rewardAddress,
        uint64 totalAddedValidators
    ) {
        if (moduleId != 4) {
            ICuratedModule module = ICuratedModule(moduleAddress);

            (
                isOperatorActive,
                ,
                rewardAddress,
                ,
                ,
                totalAddedValidators
            ) = module.getNodeOperator(operatorId, true);
        } else {
            ICSModule module = ICSModule(moduleAddress);

            isOperatorActive = module.getNodeOperatorIsActive(operatorId);

            CSMNodeOperator memory operator = module.getNodeOperator(operatorId);

            rewardAddress = operator.rewardAddress;
            totalAddedValidators = operator.totalAddedKeys;
        }
    }

    function _getOperatorRewardAddress(address moduleAddress, uint256 moduleId, uint256 operatorId)
        internal
        view
        returns (address rewardAddress)
    {
        (
            ,
            rewardAddress,
        ) = _getOperatorData(moduleAddress, moduleId, operatorId);
    }

    function _checkOperatorData(
        address moduleAddress,
        uint256 moduleId,
        uint256 operatorId,
        uint256 keysRangeStart,
        uint256 keysRangeEnd
    ) internal view {
        (
            bool isOperatorActive,
            ,
            uint64 totalAddedValidators
        ) = _getOperatorData(moduleAddress, moduleId, operatorId);

        if (!isOperatorActive) {
            revert OperatorNotActive(moduleId, operatorId);
        }

        if (
            totalAddedValidators < keysRangeEnd || keysRangeEnd < keysRangeStart
        ) {
            revert KeysIndexMismatch(
                moduleId,
                operatorId,
                keysRangeStart,
                keysRangeEnd,
                totalAddedValidators
            );
        }
    }
}
