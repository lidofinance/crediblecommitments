// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlEnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {
    OperatorsDataStorage as Operators,
    OperatorState,
    OperatorOptInOutState,
    OperatorAttributes,
    OperatorKeysRangeState,
    OperatorExtraData
} from "./lib/OperatorsDataStorage.sol";
import {ConfigDataStorage as Config, OptInOutConfig} from "./lib/ConfigDataStorage.sol";
import {ModulesDataStorage as Modules, ModuleState} from "./lib/ModulesDataStorage.sol";

import {ILidoLocator} from "./interfaces/ILidoLocator.sol";
import {StakingModule, IStakingRouter} from "./interfaces/IStakingRouter.sol";
import {StakingModuleStatus, IStakingModule} from "./interfaces/IStakingModule.sol";
import {CSMNodeOperator, ICSModule} from "./interfaces/ICSModule.sol";
import {ICuratedModule} from "./interfaces/ICuratedModule.sol";

contract CredibleCommitmentCurationProvider is
    Initializable,
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant COMMITTEE_ROLE = keccak256("COMMITTEE_ROLE");

    struct StakingModuleCache {
        bool _cached;
        uint24 id;
        StakingModuleStatus status;
        address moduleAddress;
        uint64 totalOperatorsCount;
    }

    struct NodeOperatorCache {
        bool _cached;
        uint64 id;
        uint24 moduleId;
        bool isActive;
        address rewardAddress;
        uint64 totalKeys;
    }

    struct StateCache {
        // bool _cached;
        StakingModuleCache modCache;
        NodeOperatorCache noCache;
    }

    struct OperatorOptInOutFlags {
        bool isOptedIn;
        bool isOptedOut;
        bool optInAllowed;
        bool optOutAllowed;
    }

    event OptInSucceeded(
        uint256 indexed moduleId,
        uint256 indexed operatorId,
        address managerAddress,
        uint256 keysRangeStart,
        uint256 keysRangeEnd,
        string rpcURL
    );

    error OperatorNotRegistered();
    error ManagerAddressMismatch();
    error RewardAddressMismatch();
    error OperatorNotActive();
    error ModuleNotActive();
    error OperatorAlreadyRegistered();
    error OperatorOptInNotAllowed();
    error OperatorOptOutNotAllowed();
    error KeyIndexOutOfRange();
    error KeyIndexMismatch();
    error ModuleDisabled();
    error InvalidModuleMaxValidators();
    error InvalidModuleStatus();
    error InvalidOperatorId();
    error ZeroCommitteeAddress();
    error ZeroAdminAddress();
    error ZeroOperatorManagerAddress();
    error ZeroLocatorAddress();

    ILidoLocator public immutable LIDO_LOCATOR;
    uint64 public constant DEFAULT_MAX_VALIDATORS = 1000; // Default max validators if not set explicitly

    constructor(address lidoLocator) {
        if (lidoLocator == address(0)) revert ZeroLocatorAddress();
        LIDO_LOCATOR = ILidoLocator(lidoLocator);

        _disableInitializers();
    }

    function initialize(address committeeAddress, address adminAddress) external initializer {
        if (committeeAddress == address(0)) revert ZeroCommitteeAddress();
        if (adminAddress == address(0)) revert ZeroAdminAddress();

        __Pausable_init();
        __AccessControlEnumerable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(COMMITTEE_ROLE, committeeAddress);
    }

    /// @notice Resume all operations after a pause
    function unpause() external onlyRole(COMMITTEE_ROLE) {
        _unpause();
    }

    /// @notice Pause all operations
    function pause() external onlyRole(COMMITTEE_ROLE) {
        _pause();
    }

    /// @notice Opt-in operator to the module
    /// @dev prevent a repeated optin same operator with a different manager address,
    ///      or in case when operator changed reward address in the module,
    ///      the manager's address must first be changed to the new one
    ///      from operator's reward address (see `updateManagerAddress`)
    function optIn(
        uint24 moduleId,
        uint64 operatorId,
        address managerAddress,
        uint64 newKeyIndexRangeStart,
        uint64 newKeyIndexRangeEnd,
        string memory rpcURL
    ) external whenNotPaused {
        StateCache memory cache;

        if (managerAddress == address(0)) revert ZeroOperatorManagerAddress();

        /// @dev correctness of moduleId and operatorId are checked inside
        _prepStateCache(cache, moduleId, operatorId);
        address rewardAddress = cache.noCache.rewardAddress;

        if (msg.sender != rewardAddress) {
            revert RewardAddressMismatch();
        }

        // check if the operator is active in module
        if (!cache.noCache.isActive) {
            revert OperatorNotActive();
        }

        address linkedManagerAddress = Operators._getOperatorManager(rewardAddress);
        /// @dev allow repeated opt-in after opt-out delay
        if (linkedManagerAddress != address(0) && linkedManagerAddress != managerAddress) {
            revert ManagerAddressMismatch();
        }

        OperatorOptInOutState memory optInOutState = Operators._getOperatorOptInOutState(linkedManagerAddress);
        OperatorOptInOutFlags memory flags = _calcOpyInOutFlags(optInOutState);
        if (flags.isOptedIn) {
            revert OperatorAlreadyRegistered();
        } else if (!flags.optInAllowed) {
            revert OperatorOptInNotAllowed();
        }

        // (newKeyIndexRangeStart, newKeyIndexRangeEnd) = _fixKeyIndexes(newKeyIndexRangeStart, newKeyIndexRangeEnd);
        _checkKeysRangeIsValid(cache.noCache.totalKeys, newKeyIndexRangeStart, newKeyIndexRangeEnd);
        _checkModuleParams(moduleId, newKeyIndexRangeStart, newKeyIndexRangeEnd);

        // save operator state
        Operators._setOperatorManager(rewardAddress, managerAddress);
        Operators._setOperatorAttributes(
            managerAddress, OperatorAttributes({moduleId: moduleId, operatorId: operatorId})
        );
        Operators._setOperatorOptInOutState(
            managerAddress,
            OperatorOptInOutState({optInBlock: uint64(block.number), optOutBlock: 0, isOptOutForced: false})
        );
        Operators._setOperatorKeysRangeState(
            managerAddress, OperatorKeysRangeState({indexStart: newKeyIndexRangeStart, indexEnd: newKeyIndexRangeEnd})
        );
        /// @dev no checks on rpcUrl, so it can be rewritten on repeated opt-in
        Operators._setOperatorExtraData(managerAddress, OperatorExtraData({rpcURL: rpcURL}));

        emit OptInSucceeded(moduleId, operatorId, managerAddress, newKeyIndexRangeStart, newKeyIndexRangeEnd, rpcURL);
    }

    /// @notice Opt-out operator on behalf of the operator manager
    /// @dev should be called by the operator manager address
    function optOut() external whenNotPaused {
        address managerAddress = msg.sender;

        StateCache memory cache;
        _checkOperatorByManagerAddress(cache, managerAddress);

        OperatorOptInOutState memory optInOutState = Operators._getOperatorOptInOutState(managerAddress);
        OperatorOptInOutFlags memory flags = _calcOpyInOutFlags(optInOutState);
        if (!flags.isOptedIn) {
            revert OperatorNotActive();
        } else if (!flags.optOutAllowed) {
            revert OperatorOptOutNotAllowed();
        }

        optInOutState.optOutBlock = uint64(block.number);

        Operators._setOperatorOptInOutState(managerAddress, optInOutState);

        ///todoemit event
    }

    /// @notice Opt-out operator on behalf of the committee
    function optOut(uint24 moduleId, uint64 operatorId) external onlyRole(COMMITTEE_ROLE) {
        StateCache memory cache;
        /// @dev correctness of moduleId and operatorId are checked inside
        _prepStateCache(cache, moduleId, operatorId);
        address rewardAddress = cache.noCache.rewardAddress;
        address linkedManagerAddress = Operators._getOperatorManager(rewardAddress);
        // if (linkedManagerAddress != managerAddress) {
        //     revert ManagerAddressMismatch();
        // }
        if (linkedManagerAddress == address(0)) {
            revert OperatorNotRegistered();
        }

        OperatorOptInOutState memory optInOutState = Operators._getOperatorOptInOutState(linkedManagerAddress);
        OperatorOptInOutFlags memory flags = _calcOpyInOutFlags(optInOutState);
        if (!flags.isOptedIn) {
            revert OperatorNotActive();
        }
        /// @dev ignore optOutAllowed, as the committee can force opt-out

        optInOutState.optOutBlock = uint64(block.number);
        optInOutState.isOptOutForced = true;

        Operators._setOperatorOptInOutState(linkedManagerAddress, optInOutState);

        ///todoemit event
    }

    function updateKeysRange(uint64 newKeyIndexRangeStart, uint64 newKeyIndexRangeEnd) external whenNotPaused {
        address managerAddress = msg.sender;

        OperatorAttributes memory attr = Operators._getOperatorAttributes(managerAddress);
        if (attr.moduleId == 0) {
            revert OperatorNotRegistered();
        }

        StateCache memory cache;
        /// @dev correctness of moduleId and operatorId are checked inside
        _prepStateCache(cache, attr.moduleId, attr.operatorId);
        address rewardAddress = cache.noCache.rewardAddress;
        address linkedManagerAddress = Operators._getOperatorManager(rewardAddress);
        if (linkedManagerAddress != managerAddress) {
            revert ManagerAddressMismatch();
        }

        OperatorOptInOutFlags memory flags = _calcOpyInOutFlags(Operators._getOperatorOptInOutState(managerAddress));
        if (!flags.isOptedIn) {
            revert OperatorNotActive();
        }

        OperatorKeysRangeState memory keysRangeState = Operators._getOperatorKeysRangeState(managerAddress);
        if (
            newKeyIndexRangeStart > keysRangeState.indexStart || newKeyIndexRangeEnd < keysRangeState.indexEnd
                || (newKeyIndexRangeStart == keysRangeState.indexStart && newKeyIndexRangeEnd == keysRangeState.indexEnd)
        ) {
            revert KeyIndexMismatch();
        }

        // (newKeyIndexRangeStart, newKeyIndexRangeEnd) = _fixKeyIndexes(newKeyIndexRangeStart, newKeyIndexRangeEnd);
        _checkKeysRangeIsValid(cache.noCache.totalKeys, newKeyIndexRangeStart, newKeyIndexRangeEnd);
        _checkModuleParams(cache.noCache.moduleId, newKeyIndexRangeStart, newKeyIndexRangeEnd);

        // save operator state
        Operators._setOperatorKeysRangeState(
            managerAddress, OperatorKeysRangeState({indexStart: newKeyIndexRangeStart, indexEnd: newKeyIndexRangeEnd})
        );

        ///todoemit event
    }

    function getOperatorByManagerAddress(address managerAddress)
        external
        view
        returns (
            OperatorState memory state,
            OperatorOptInOutFlags memory flags,
            address operatorRewardAddress,
            address linkedManagerAddress
        )
    {
        StateCache memory cache;

        _checkOperatorByManagerAddress(cache, managerAddress);
        linkedManagerAddress = managerAddress;
        state = Operators._getOperatorState(managerAddress);
        operatorRewardAddress = cache.noCache.rewardAddress;
        flags = _calcOpyInOutFlags(state.optInOutState);
    }

    function getOperatorByRewardAddress(address rewardAddress)
        external
        view
        returns (
            OperatorState memory state,
            OperatorOptInOutFlags memory flags,
            address operatorRewardAddress,
            address linkedManagerAddress
        )
    {
        StateCache memory cache;

        /// @dev first check if the manager exists for the current operator's reward address
        linkedManagerAddress = Operators._getOperatorManager(rewardAddress);
        if (linkedManagerAddress == address(0)) {
            revert OperatorNotRegistered();
        }

        state = Operators._getOperatorState(linkedManagerAddress);

        // if (state.attr.moduleId == 0) {
        //     revert OperatorNotRegistered();
        // }

        /// @dev correctness of moduleId and operatorId are checked inside
        _prepStateCache(cache, state.attr.moduleId, state.attr.operatorId);
        operatorRewardAddress = cache.noCache.rewardAddress;
        /// @dev check if actual reward address is the same as the one in the operator's state
        if (operatorRewardAddress != rewardAddress) {
            revert RewardAddressMismatch();
        }
        flags = _calcOpyInOutFlags(state.optInOutState);
    }

    function getOperatorByAttr(uint24 moduleId, uint64 operatorId)
        external
        view
        returns (
            OperatorState memory state,
            OperatorOptInOutFlags memory flags,
            address operatorRewardAddress,
            address linkedManagerAddress
        )
    {
        StateCache memory cache;

        /// @dev correctness of moduleId and operatorId are checked inside
        _prepStateCache(cache, moduleId, operatorId);
        operatorRewardAddress = cache.noCache.rewardAddress;

        /// @dev first check if the manager exists for the current operator's reward address
        linkedManagerAddress = Operators._getOperatorManager(operatorRewardAddress);
        if (linkedManagerAddress == address(0)) {
            revert OperatorNotRegistered();
        }

        state = Operators._getOperatorState(linkedManagerAddress);
        /// @dev check case when the operator's manager and reward addresses were used in different module
        if (state.attr.moduleId != moduleId || state.attr.operatorId != operatorId) {
            revert OperatorNotRegistered();
        }
        flags = _calcOpyInOutFlags(state.optInOutState);
    }

    function _checkOperatorByManagerAddress(StateCache memory cache, address managerAddress) internal view {
        OperatorAttributes memory attr = Operators._getOperatorAttributes(managerAddress);
        if (attr.moduleId == 0) {
            revert OperatorNotRegistered();
        }

        /// @dev correctness of moduleId and operatorId are checked inside
        _prepStateCache(cache, attr.moduleId, attr.operatorId);
        address rewardAddress = cache.noCache.rewardAddress;
        address linkedManagerAddress = Operators._getOperatorManager(rewardAddress);
        if (linkedManagerAddress != managerAddress) {
            revert ManagerAddressMismatch();
        }
    }

    /// @notice update max validators for the module
    /// @dev zero value means disable all future opt-ins
    function setMaxValidatorsForStakingModule(uint24 moduleId, uint64 maxValidators)
        external
        onlyRole(COMMITTEE_ROLE)
    {
        StateCache memory cache;
        /// @dev check moduleId via staking router
        _prepStakingModuleCache(cache, moduleId);

        ///todo: upper cap for maxValidators?
        // if (maxValidators > xxx) {
        //     revert InvalidModuleMaxValidators();
        // }

        ModuleState memory state = Modules._getModuleState(moduleId);
        if (!state.isActive) {
            revert ModuleNotActive();
        }
        state.maxValidators = maxValidators;
        Modules._setModuleState(moduleId, state);

        ///todo emit event
    }

    /// @notice update min opt-in and opt-out delay durations
    function setConfigOptInOutDurations(uint64 optInMinDurationBlocks, uint64 optOutDelayDurationBlocks)
        external
        onlyRole(COMMITTEE_ROLE)
    {
        _setConfigOptInOutDurations(optInMinDurationBlocks, optOutDelayDurationBlocks);
    }

    function _setConfigOptInOutDurations(uint64 optInMinDurationBlocks, uint64 optOutDelayDurationBlocks) internal {
        Config._setConfigOptInOut(
            OptInOutConfig({
                optInMinDurationBlocks: optInMinDurationBlocks,
                optOutDelayDurationBlocks: optOutDelayDurationBlocks
            })
        );

        ///todo emit event
    }

    function _checkModuleParams(uint24 moduleId, uint64 startIndex, uint64 endIndex) internal view {
        ModuleState memory state = Modules._getModuleState(moduleId);
        if (!state.isActive) {
            revert ModuleDisabled();
        }
        uint64 totalKeys = endIndex - startIndex + 1;
        uint64 maxValidators = state.maxValidators == 0 ? DEFAULT_MAX_VALIDATORS : state.maxValidators;

        if (totalKeys > maxValidators) {
            revert InvalidModuleMaxValidators();
        }
    }

    function _checkKeysRangeIsValid(uint64 totalKeys, uint64 startIndex, uint64 endIndex) internal pure {
        if (startIndex > endIndex) {
            revert KeyIndexMismatch();
        }

        if (endIndex >= totalKeys || startIndex >= totalKeys) {
            revert KeyIndexOutOfRange();
        }
    }

    function _calcOpyInOutFlags(OperatorOptInOutState memory optInOutState)
        internal
        view
        returns (OperatorOptInOutFlags memory flags)
    {
        uint64 blockNumber = uint64(block.number);
        OptInOutConfig memory optInOutCfg = Config._getConfigOptInOut();

        bool isOptedOut = optInOutState.optOutBlock > 0
            && optInOutState.optOutBlock + optInOutCfg.optOutDelayDurationBlocks < blockNumber;
        bool isOptedIn = optInOutState.optInBlock > 0 && !isOptedOut;
        bool optInAllowed = !isOptedIn && !optInOutState.isOptOutForced;
        bool optOutAllowed = isOptedIn && optInOutState.optInBlock + optInOutCfg.optInMinDurationBlocks < blockNumber;

        return OperatorOptInOutFlags({
            isOptedIn: isOptedIn,
            isOptedOut: isOptedOut,
            optInAllowed: optInAllowed,
            optOutAllowed: optOutAllowed
        });
    }

    // function _fixKeyIndexes(uint256 startIndex, uint256 endIndex)
    //     internal
    //     pure
    //     returns (uint256 fixedStartIndex, uint256 fixedEndIndex)
    // {
    //     /// @dev flip values if the start index is greater than the end index
    //     if (startIndex < endIndex) {
    //         (startIndex, endIndex) = (endIndex, startIndex);
    //     }
    //     return (startIndex, endIndex);
    // }

    /// CACHE

    /// @notice Get the staking router address from LidoLocator
    function _getStakingRouter() internal view returns (IStakingRouter) {
        return IStakingRouter(LIDO_LOCATOR.stakingRouter());
    }

    /// @notice Prepare the cache for the staking module and node operator
    function _prepStateCache(StateCache memory cache, uint24 moduleId, uint64 operatorId) internal view {
        _prepStakingModuleCache(cache, moduleId);
        _prepNodeOperatorCache(cache, operatorId);
    }

    /// @dev module id validity check is done in the staking router
    function _prepStakingModuleCache(StateCache memory cache, uint24 moduleId) internal view {
        if (cache.modCache._cached && cache.modCache.id == moduleId) {
            return;
        }
        StakingModule memory module = _getStakingRouter().getStakingModule(moduleId);

        cache.modCache = StakingModuleCache({
            _cached: true,
            id: moduleId,
            status: StakingModuleStatus(module.status),
            moduleAddress: module.stakingModuleAddress,
            totalOperatorsCount: uint64(IStakingModule(module.stakingModuleAddress).getNodeOperatorsCount())
        });
    }

    function _prepNodeOperatorCache(StateCache memory cache, uint64 operatorId) internal view {
        if (cache.noCache._cached && cache.noCache.id == operatorId && cache.noCache.moduleId == cache.modCache.id) {
            return;
        }
        /// @dev check if module is not stopped
        // if (cache.modCache.status == StakingModuleStatus.Stopped) {
        //     revert InvalidModuleStatus();
        // }

        /// @dev check if the operatorId is valid
        if (operatorId >= cache.modCache.totalOperatorsCount) {
            revert InvalidOperatorId();
        }

        bool isActive;
        address rewardAddress;
        uint64 totalKeys;
        /// @dev hardcoded check for the CSModule id
        if (cache.noCache.id == 4) {
            ICSModule module = ICSModule(cache.modCache.moduleAddress);
            isActive = module.getNodeOperatorIsActive(operatorId);
            CSMNodeOperator memory operator = module.getNodeOperator(operatorId);
            rewardAddress = operator.rewardAddress;
            totalKeys = operator.totalAddedKeys;
        } else {
            ICuratedModule module = ICuratedModule(cache.modCache.moduleAddress);
            (isActive,, rewardAddress,,, totalKeys) = module.getNodeOperator(operatorId, false);
        }

        cache.noCache = NodeOperatorCache({
            _cached: true,
            id: operatorId,
            moduleId: cache.modCache.id,
            isActive: isActive,
            rewardAddress: rewardAddress,
            totalKeys: totalKeys
        });
    }

    /// SERVICE FUNCTIONS

    /// @notice UUPS proxy upgrade authorization
    /// @dev Only the default admin role can authorize an upgrade
    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
