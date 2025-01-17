// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlEnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {
    CCCPDataStorage as DS,
    OperatorState,
    OperatorOptInOutState,
    OperatorAttributes,
    OperatorKeysRangeState,
    OperatorExtraData,
    ModuleState,
    Config
} from "./lib/CCCPDataStorage.sol";

import {ILidoLocator} from "./interfaces/ILidoLocator.sol";
import {StakingModule, IStakingRouter} from "./interfaces/IStakingRouter.sol";
import {StakingModuleStatus, IStakingModule} from "./interfaces/IStakingModule.sol";
import {CSMNodeOperator, ICSModule} from "./interfaces/ICSModule.sol";
import {ICuratedModule} from "./interfaces/ICuratedModule.sol";

contract CredibleCommitmentCurationProvider is
    Initializable,
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable
{
    struct LidoOperatorCache {
        uint24 moduleId;
        address moduleAddress;
        StakingModuleStatus moduleStatus;
        uint64 operatorId;
        address rewardAddress;
        uint64 totalKeys;
        bool isActive;
    }

    struct OperatorOptInOutFlags {
        bool isOptedIn;
        bool isOptedOut;
        bool optInAllowed;
        bool optOutAllowed;
    }

    bytes32 public constant COMMITTEE_ROLE = keccak256("COMMITTEE_ROLE");
    ILidoLocator public immutable LIDO_LOCATOR;
    // hardcoded CSModule type, used for the operator's state retrieval
    bytes32 internal immutable CS_MODULE_TYPE;
    // Default max validators if not set explicitly
    uint64 public immutable DEFAULT_MAX_VALIDATORS;

    event OptInSucceeded(uint256 indexed moduleId, uint256 indexed operatorId, address managerAddress);
    event OptOutRequested(uint256 indexed moduleId, uint256 indexed operatorId, bool isForced);
    event KeyRangeUpdated(
        uint256 indexed moduleId, uint256 indexed operatorId, uint256 keysRangeStart, uint256 keysRangeEnd
    );
    event RPCUrlUpdated(uint256 indexed moduleId, uint256 indexed operatorId, string rpcURL);
    event ModuleMaxValidatorsUpdated(uint256 indexed moduleId, uint256 maxValidators);
    event ModuleDisabledUpdated(uint256 indexed moduleId, bool isDisabled);
    event OptInOutConfigUpdated(uint256 optInMinDurationBlocks, uint256 optOutDelayDurationBlocks);

    error OperatorNotRegistered();
    error ManagerAddressMismatch();
    error RewardAddressMismatch();
    error OperatorNotActive();
    error ModuleDisabled();
    error SameValue();
    error OperatorAlreadyRegistered();
    error OperatorOptInNotAllowed();
    error OperatorOptOutNotAllowed();
    error KeyIndexOutOfRange();
    error KeyIndexMismatch();
    error InvalidModuleMaxValidators();
    error InvalidModuleStatus();
    error InvalidOperatorId();
    error InvalidModuleId();
    error ZeroCommitteeAddress();
    error ZeroOperatorManagerAddress();
    error ZeroLocatorAddress();

    constructor(address lidoLocator, bytes32 csModuleType, uint64 defaultMaxValidators) {
        if (lidoLocator == address(0)) revert ZeroLocatorAddress();
        LIDO_LOCATOR = ILidoLocator(lidoLocator);

        CS_MODULE_TYPE = csModuleType;
        DEFAULT_MAX_VALIDATORS = defaultMaxValidators;

        _disableInitializers();
    }

    function initialize(address committeeAddress, uint64 optInMinDurationBlocks, uint64 optOutDelayDurationBlocks, uint64 defaultModuleMaxValidators, uint64 defaultBlockGasLimit)
        external
        initializer
    {
        if (committeeAddress == address(0)) revert ZeroCommitteeAddress();

        __Pausable_init();
        __AccessControlEnumerable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, committeeAddress);
        _grantRole(COMMITTEE_ROLE, committeeAddress);

        _setConfigOptInOutDurations(optInMinDurationBlocks, optOutDelayDurationBlocks);
        DS._setConfigOptInOut(
            Config({
                optInMinDurationBlocks: optInMinDurationBlocks,
                optOutDelayDurationBlocks: optOutDelayDurationBlocks
            })
        );

        emit OptInOutConfigUpdated(optInMinDurationBlocks, optOutDelayDurationBlocks);
    }

    /// @notice Resume all operations after a pause
    function unpause() external onlyRole(COMMITTEE_ROLE) {
        _unpause();
    }

    /// @notice Pause all operations
    function pause() external onlyRole(COMMITTEE_ROLE) {
        _pause();
    }

    /// @notice Update the max validators for the module
    function setModuleMaxValidators(uint24 moduleId, uint64 maxValidators) external onlyRole(COMMITTEE_ROLE) {
        /// @dev check moduleId via staking router
        LidoOperatorCache memory cache;
        _loadLidoModuleData(cache, moduleId);

        ///todo: upper cap for maxValidators?
        // if (maxValidators > xxx) {
        //     revert InvalidModuleMaxValidators();
        // }

        ModuleState memory state = DS._getModuleState(moduleId);
        state.maxValidators = maxValidators;
        DS._setModuleState(moduleId, state);

        emit ModuleMaxValidatorsUpdated(moduleId, maxValidators);
    }

    /// @notice Disable/enable the module
    /// @dev operators in disabled modules are automatically considered as opted-out
    function setModuleDisabled(uint24 moduleId, bool isDisabled) external onlyRole(COMMITTEE_ROLE) {
        /// @dev check moduleId via staking router
        LidoOperatorCache memory cache;
        _loadLidoModuleData(cache, moduleId);

        ModuleState memory state = DS._getModuleState(moduleId);
        state.isDisabled = isDisabled;
        DS._setModuleState(moduleId, state);

        emit ModuleDisabledUpdated(moduleId, isDisabled);
    }

    /// @notice update min opt-in and opt-out delay durations
    function setConfigOptInOutDurations(uint64 optInMinDurationBlocks, uint64 optOutDelayDurationBlocks)
        external
        onlyRole(COMMITTEE_ROLE)
    {
        _setConfigOptInOutDurations(optInMinDurationBlocks, optOutDelayDurationBlocks);
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
        LidoOperatorCache memory cache;

        if (managerAddress == address(0)) revert ZeroOperatorManagerAddress();

        /// @dev correctness of moduleId and operatorId are checked inside
        _loadLidoNodeOperator(cache, moduleId, operatorId);
        address rewardAddress = cache.noCache.rewardAddress;

        if (msg.sender != rewardAddress) {
            revert RewardAddressMismatch();
        }

        // check if the operator is active in Lido module
        if (!cache.noCache.isActive) {
            revert OperatorNotActive();
        }

        address linkedManagerAddress = DS._getOperatorManager(rewardAddress);
        /// @dev allow repeated opt-in after opt-out delay
        if (linkedManagerAddress != address(0) && linkedManagerAddress != managerAddress) {
            revert ManagerAddressMismatch();
        }

        OperatorOptInOutState memory optInOutState = DS._getOperatorOptInOutState(linkedManagerAddress);
        OperatorOptInOutFlags memory flags = _calcOptInOutFlags(optInOutState);
        if (flags.isOptedIn) {
            revert OperatorAlreadyRegistered();
        } else if (!flags.optInAllowed) {
            revert OperatorOptInNotAllowed();
        }

        _checkKeysRangeIsValid(cache.noCache.totalKeys, newKeyIndexRangeStart, newKeyIndexRangeEnd);
        _checkModuleParams(moduleId, newKeyIndexRangeStart, newKeyIndexRangeEnd);

        // save operator state
        DS._setOperatorManager(rewardAddress, managerAddress);
        DS._setOperatorAttributes(managerAddress, OperatorAttributes({moduleId: moduleId, operatorId: operatorId}));
        DS._setOperatorOptInOutState(
            managerAddress,
            OperatorOptInOutState({optInBlock: uint64(block.number), optOutBlock: 0, isOptOutForced: false})
        );
        DS._setOperatorKeysRangeState(
            managerAddress, OperatorKeysRangeState({indexStart: newKeyIndexRangeStart, indexEnd: newKeyIndexRangeEnd})
        );
        /// @dev no checks on rpcUrl, so it can be rewritten on repeated opt-in
        DS._setOperatorExtraData(managerAddress, OperatorExtraData({rpcURL: rpcURL}));

        emit OptInSucceeded(moduleId, operatorId, managerAddress);
        emit KeyRangeUpdated(moduleId, operatorId, newKeyIndexRangeStart, newKeyIndexRangeEnd);
        // emit RPCUrlUpdated(moduleId, operatorId, rpcURL);
    }

    /// @notice Opt-out operator on behalf of the operator manager
    /// @dev should be called by the operator manager address
    function optOut() external whenNotPaused {
        address managerAddress = msg.sender;

        LidoOperatorCache memory cache;
        _checkOperatorByManagerAddress(cache, managerAddress);

        OperatorOptInOutState memory optInOutState = DS._getOperatorOptInOutState(managerAddress);
        OperatorOptInOutFlags memory flags = _calcOptInOutFlags(optInOutState);
        if (!flags.isOptedIn) {
            revert OperatorNotActive();
        } else if (!flags.optOutAllowed) {
            revert OperatorOptOutNotAllowed();
        }

        optInOutState.optOutBlock = uint64(block.number);

        DS._setOperatorOptInOutState(managerAddress, optInOutState);

        emit OptOutRequested(cache.noCache.moduleId, cache.noCache.id, false);
    }

    /// @notice Opt-out operator on behalf of the committee
    function optOut(uint24 moduleId, uint64 operatorId) external onlyRole(COMMITTEE_ROLE) {
        LidoOperatorCache memory cache;
        /// @dev correctness of moduleId and operatorId are checked inside
        _loadLidoNodeOperator(cache, moduleId, operatorId);
        address rewardAddress = cache.noCache.rewardAddress;
        address linkedManagerAddress = DS._getOperatorManager(rewardAddress);
        if (linkedManagerAddress == address(0)) {
            revert OperatorNotRegistered();
        }

        OperatorOptInOutState memory optInOutState = DS._getOperatorOptInOutState(linkedManagerAddress);
        OperatorOptInOutFlags memory flags = _calcOptInOutFlags(optInOutState);
        if (!flags.isOptedIn) {
            revert OperatorNotActive();
        }
        /// @dev ignore optOutAllowed, as the committee can force opt-out

        optInOutState.optOutBlock = uint64(block.number);
        optInOutState.isOptOutForced = true;

        DS._setOperatorOptInOutState(linkedManagerAddress, optInOutState);

        emit OptOutRequested(cache.noCache.moduleId, cache.noCache.id, true);
    }

    function updateKeysRange(uint64 newKeyIndexRangeStart, uint64 newKeyIndexRangeEnd) external whenNotPaused {
        address managerAddress = msg.sender;

        LidoOperatorCache memory cache;
        _checkOperatorByManagerAddress(cache, managerAddress);

        OperatorOptInOutFlags memory flags = _calcOptInOutFlags(DS._getOperatorOptInOutState(managerAddress));
        if (!flags.isOptedIn) {
            revert OperatorNotActive();
        }

        OperatorKeysRangeState memory keysRangeState = DS._getOperatorKeysRangeState(managerAddress);
        if (
            newKeyIndexRangeStart > keysRangeState.indexStart || newKeyIndexRangeEnd < keysRangeState.indexEnd
                || (newKeyIndexRangeStart == keysRangeState.indexStart && newKeyIndexRangeEnd == keysRangeState.indexEnd)
        ) {
            revert KeyIndexMismatch();
        }

        _checkKeysRangeIsValid(cache.noCache.totalKeys, newKeyIndexRangeStart, newKeyIndexRangeEnd);
        _checkModuleParams(cache.noCache.moduleId, newKeyIndexRangeStart, newKeyIndexRangeEnd);

        // save operator state
        DS._setOperatorKeysRangeState(
            managerAddress, OperatorKeysRangeState({indexStart: newKeyIndexRangeStart, indexEnd: newKeyIndexRangeEnd})
        );

        emit KeyRangeUpdated(cache.noCache.moduleId, cache.noCache.id, newKeyIndexRangeStart, newKeyIndexRangeEnd);
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
        LidoOperatorCache memory cache;

        _checkOperatorByManagerAddress(cache, managerAddress);
        linkedManagerAddress = managerAddress;
        state = DS._getOperatorState(managerAddress);
        operatorRewardAddress = cache.noCache.rewardAddress;
        flags = _calcOptInOutFlags(state.optInOutState);
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
        LidoOperatorCache memory cache;

        /// @dev first check if the manager exists for the current operator's reward address
        linkedManagerAddress = DS._getOperatorManager(rewardAddress);
        if (linkedManagerAddress == address(0)) {
            revert OperatorNotRegistered();
        }

        state = DS._getOperatorState(linkedManagerAddress);

        // if (state.attr.moduleId == 0) {
        //     revert OperatorNotRegistered();
        // }

        /// @dev correctness of moduleId and operatorId are checked inside
        _loadLidoNodeOperator(cache, state.attr.moduleId, state.attr.operatorId);
        operatorRewardAddress = cache.noCache.rewardAddress;
        /// @dev check if actual reward address is the same as the one in the operator's state
        if (operatorRewardAddress != rewardAddress) {
            revert RewardAddressMismatch();
        }
        flags = _calcOptInOutFlags(state.optInOutState);
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
        LidoOperatorCache memory cache;

        /// @dev correctness of moduleId and operatorId are checked inside
        _loadLidoNodeOperator(cache, moduleId, operatorId);
        operatorRewardAddress = cache.noCache.rewardAddress;

        /// @dev first check if the manager exists for the current operator's reward address
        linkedManagerAddress = DS._getOperatorManager(operatorRewardAddress);
        if (linkedManagerAddress == address(0)) {
            revert OperatorNotRegistered();
        }

        state = DS._getOperatorState(linkedManagerAddress);
        /// @dev check case when the operator's manager and reward addresses were used in different module
        if (state.attr.moduleId != moduleId || state.attr.operatorId != operatorId) {
            revert OperatorNotRegistered();
        }
        flags = _calcOptInOutFlags(state.optInOutState);
    }

    /// @notice update max validators for the module
    /// @dev zero value means disable all future opt-ins
    function _setConfigOptInOutDurations(uint64 optInMinDurationBlocks, uint64 optOutDelayDurationBlocks) internal {
        DS._setConfigOptInOut(
            Config({
                optInMinDurationBlocks: optInMinDurationBlocks,
                optOutDelayDurationBlocks: optOutDelayDurationBlocks
            })
        );

        emit OptInOutConfigUpdated(optInMinDurationBlocks, optOutDelayDurationBlocks);
    }

    function _checkModuleParams(uint24 moduleId, uint64 startIndex, uint64 endIndex) internal view {
        ///todo check max validators sum per module
        ModuleState memory state = DS._getModuleState(moduleId);
        if (!state.isActive) {
            revert ModuleDisabled();
        }
        uint64 totalKeys = endIndex - startIndex + 1;
        uint64 maxValidators = state.maxValidators == 0 ? DEFAULT_MAX_VALIDATORS : state.maxValidators;

        if (totalKeys > maxValidators) {
            revert InvalidModuleMaxValidators();
        }
    }

    function _checkOperatorByManagerAddress(LidoOperatorCache memory cache, address managerAddress) internal view {
        OperatorAttributes memory attr = DS._getOperatorAttributes(managerAddress);
        if (attr.moduleId == 0) {
            revert OperatorNotRegistered();
        }

        /// @dev correctness of moduleId and operatorId are checked inside
        _loadLidoNodeOperator(cache, attr.moduleId, attr.operatorId);
        address rewardAddress = cache.noCache.rewardAddress;
        address linkedManagerAddress = DS._getOperatorManager(rewardAddress);
        if (linkedManagerAddress != managerAddress) {
            revert ManagerAddressMismatch();
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

    function _calcOptInOutFlags(OperatorOptInOutState memory optInOutState)
        internal
        view
        returns (OperatorOptInOutFlags memory flags)
    {
        uint64 blockNumber = uint64(block.number);
        Config memory optInOutCfg = DS._getConfigOptInOut();

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

    /// CACHE

    /// @notice Get the staking router address from LidoLocator
    function _getStakingRouter() internal view returns (IStakingRouter) {
        return IStakingRouter(LIDO_LOCATOR.stakingRouter());
    }

    /// @notice Prepare the cache for the staking module and node operator
    function _loadLidoNodeOperator(LidoOperatorCache memory cache, uint24 moduleId, uint64 operatorId) internal view {
        _loadLidoModuleData(no, moduleId);
        _loadLidoNodeOperatorData(no, operatorId);
    }


    function _loadLidoModuleData(LidoOperatorCache memory cache, uint24 moduleId) internal view {
        /// @dev module id validity check is done in the staking router
        StakingModule memory module = _getStakingRouter().getStakingModule(moduleId);

        no.moduleId = moduleId;
        no.moduleAddress = module.stakingModuleAddress;
        no.moduleStatus = StakingModuleStatus(module.status);
    }

    function _loadLidoNodeOperatorData(LidoOperatorCache memory cache, uint64 operatorId) internal view {
        if (no.moduleId == 0) {
            revert InvalidModuleId();
        }

        /// @dev check if module is not stopped
        // if (no.moduleStatus == StakingModuleStatus.Stopped) {
        //     revert InvalidModuleStatus();
        // }

        /// @dev check if the operatorId is valid
        uint64 totalOperatorsCount = uint64(IStakingModule(no.moduleAddress).getNodeOperatorsCount());
        if (operatorId >= totalOperatorsCount) {
            revert InvalidOperatorId();
        }

        /// @dev check for the CSModule type
        bytes2 moduleType = IStakingModule(no.moduleAddress).getType();
        if (moduleType == CS_MODULE_TYPE) {
            ICSModule module = ICSModule(no.moduleAddress);
            no.isActive = module.getNodeOperatorIsActive(operatorId);
            CSMNodeOperator memory operator = module.getNodeOperator(operatorId);
            no.rewardAddress = operator.rewardAddress;
            no.totalKeys = operator.totalAddedKeys;
        } else {
            ICuratedModule module = ICuratedModule(no.moduleAddress);
            (no.isActive,, no.rewardAddress,,, no.totalKeys) = module.getNodeOperator(operatorId, false);
        }

    }
}
