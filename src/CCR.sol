// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlEnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {CCROperatorStatesStorage} from "./lib/CCROperatorStatesStorage.sol";
import {CCRConfigStorage} from "./lib/CCRConfigStorage.sol";
import {ICCR} from "./interfaces/ICCR.sol";

import {ILidoLocator} from "./interfaces/ILidoLocator.sol";
import {StakingModule, IStakingRouter} from "./interfaces/IStakingRouter.sol";
import {IStakingModule} from "./interfaces/IStakingModule.sol";
import {CSMNodeOperator, ICSModule} from "./interfaces/ICSModule.sol";
import {ICuratedModule} from "./interfaces/ICuratedModule.sol";

/**
 * @title CCR
 * @notice CredibleCommitmentCurationProvider contract
 */
contract CCR is
    ICCR,
    Initializable,
    CCRConfigStorage,
    CCROperatorStatesStorage,
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable
{
    struct LidoOperatorCache {
        uint24 moduleId;
        address moduleAddress;
        uint64 operatorId;
        address rewardAddress;
        uint64 totalKeys;
        bool isActive;
    }

    struct OperatorOptInOutFlags {
        bool isOptedIn;
        // bool isOptedOut;
        bool isOptInDelayed;
        bool isOptOutDelayed;
    }

    bytes32 public constant COMMITTEE_ROLE = keccak256("COMMITTEE_ROLE");
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    bytes32 public constant RESUME_ROLE = keccak256("RESUME_ROLE");
    uint64 public constant MAX_COMMITMENTS = 64;

    ILidoLocator public immutable LIDO_LOCATOR;
    // CSModule type, used for the operator's state retrieval
    bytes32 internal immutable CS_MODULE_TYPE;

    event OptInSucceeded(uint256 indexed moduleId, uint256 indexed operatorId);
    event OptOutRequested(uint256 indexed moduleId, uint256 indexed operatorId, bool isForced);
    event UnblockOperator(uint256 indexed moduleId, uint256 indexed operatorId);

    // event KeyRangeUpdated(uint256 indexed moduleId, uint256 indexed operatorId, uint256 indexStart, uint256 indexEnd);
    event OperatorCommitmentAdded(
        uint256 indexed moduleId, uint256 indexed operatorId, uint256 keyIndexStart, uint256 keyIndexEnd, string rpcURL
    );
    event OperatorCommitmentDeleted(
        uint256 indexed moduleId, uint256 indexed operatorId, uint256 keyIndexStart, uint256 keyIndexEnd
    );
    event OperatorManagerUpdated(uint256 indexed moduleId, uint256 indexed operatorId, address manager);
    event OperatorDelegateAdded(uint256 indexed moduleId, uint256 indexed operatorId, bytes key);
    event OperatorDelegateDeleted(uint256 indexed moduleId, uint256 indexed operatorId, bytes key);
    // event RPCUrlUpdated(uint256 indexed moduleId, uint256 indexed operatorId, string rpcURL);
    event ConfigUpdated(
        uint256 optInDelayBlocks,
        uint256 optOutDelayBlocks,
        uint256 defaultOperatorMaxKeys,
        uint256 defaultBlockGasLimit
    );
    event ModuleConfigUpdated(uint256 indexed moduleId, bool isDisabled, uint256 operatorMaxKeys, uint64 blockGasLimit);

    error RewardAddressMismatch();
    error OperatorNotActive();
    error OperatorBlocked();
    error ModuleDisabled();
    error OperatorOptedIn();
    error OperatorOptedOut();
    error OperatorOptInNotAllowed();
    error OperatorOptOutNotAllowed();
    error OperatorOptOutInProgress();
    error KeyIndexOutOfRange();
    error KeyRangeExceedMaxKeys();
    error KeyIndexOverlapExisting();
    error KeyIndexMismatch();
    error InvalidOperatorId();
    error InvalidModuleId();
    error ZeroCommitteeAddress();
    error ZeroOperatorManagerAddress();
    error ZeroLocatorAddress();
    error CommitmentsLimitReached();
    error OptInActionDelayed();
    error OptOutActionDelayed();

    constructor(address lidoLocator, bytes32 csModuleType) {
        if (lidoLocator == address(0)) revert ZeroLocatorAddress();
        LIDO_LOCATOR = ILidoLocator(lidoLocator);
        CS_MODULE_TYPE = csModuleType;

        _disableInitializers();
    }

    function initialize(
        address committeeAddress,
        uint64 optInDelayBlocks,
        uint64 optOutDelayBlocks,
        uint64 defaultOperatorMaxKeys,
        uint64 defaultBlockGasLimit
    ) external initializer {
        if (committeeAddress == address(0)) revert ZeroCommitteeAddress();

        __Pausable_init();
        __AccessControlEnumerable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, committeeAddress);
        _grantRole(COMMITTEE_ROLE, committeeAddress);
        _grantRole(PAUSE_ROLE, committeeAddress);
        _grantRole(RESUME_ROLE, committeeAddress);

        _updateConfig(optInDelayBlocks, optOutDelayBlocks, defaultOperatorMaxKeys, defaultBlockGasLimit);

        ///todo: pass module Ids to disable them at the start
    }

    /// @notice Resume all operations after a pause
    function unpause() external onlyRole(RESUME_ROLE) {
        _unpause();
    }

    /// @notice Pause all operations
    function pause() external onlyRole(PAUSE_ROLE) {
        _pause();
    }

    /// @notice Opt-in operator to the module
    /// @dev allows a repeated optin with different manager address
    function optIn(
        uint24 moduleId,
        uint64 operatorId,
        address manager,
        uint64 indexStart,
        uint64 indexEnd,
        string calldata rpcURL
    ) external whenNotPaused {
        if (manager == address(0)) revert ZeroOperatorManagerAddress();

        LidoOperatorCache memory _c;
        /// @dev correctness of moduleId and operatorId are checked inside
        _loadLidoNodeOperator(_c, moduleId, operatorId);

        // check if the caller is the operator's reward address
        if (msg.sender != _c.rewardAddress) {
            revert RewardAddressMismatch();
        }

        // check if the operator is active in Lido module
        if (!_c.isActive) {
            revert OperatorNotActive();
        }

        uint256 opKey = __encOpKey(moduleId, operatorId);
        if (_getIsOperatorBlocked(opKey)) {
            revert OperatorBlocked();
        }

        // check if the operator is already has the state
        OptInOutState memory optInOutState = _getOperatorOptInOutState(opKey);
        OperatorOptInOutFlags memory flags = _calcOptInOutFlags(optInOutState);
        if (flags.isOptedIn) {
            revert OperatorOptedIn();
        }
        _checkOptInDelayed(flags);

        // save operator state
        /// @dev also checks if the proposed manager is already registered for different operator
        _setOperatorManager(opKey, manager);
        emit OperatorManagerUpdated(moduleId, operatorId, manager);

        /// @dev clear the previous commitments (could be expensive!)
        _delOperatorAllCommitments(opKey);

        _checkAndAddCommitment(_c, opKey, indexStart, indexEnd, rpcURL);
        emit OperatorCommitmentAdded(moduleId, operatorId, indexStart, indexEnd, rpcURL);

        emit OptInSucceeded(moduleId, operatorId);

        optInOutState.optInBlock = uint64(block.number);
        optInOutState.optOutBlock = 0;
        _setOptInOutStateWithOptInDelay(opKey, optInOutState);
    }

    /// @notice Opt-out operator on behalf of the operator manager
    /// @dev should be called by the operator manager address
    function optOut() external whenNotPaused {
        (uint256 opKey, OptInOutState memory optInOutState, OperatorOptInOutFlags memory flags) =
            _checkOptInAndLoadStateByManager(msg.sender);
        _checkOptInDelayed(flags);

        optInOutState.optOutBlock = uint64(block.number);
        _setOptInOutStateWithOptOutDelay(opKey, optInOutState);

        (uint24 moduleId, uint64 operatorId) = __decOpKey(opKey);
        emit OptOutRequested(moduleId, operatorId, false);
    }

    /// @notice Opt-out operator on behalf of the committee
    function optOut(uint24 moduleId, uint64 operatorId) external onlyRole(COMMITTEE_ROLE) {
        uint256 opKey = _getOpKeyById(moduleId, operatorId);
        (OptInOutState memory optInOutState,) = _checkOptInAndLoadState(opKey);
        /// @dev ignore isOptOutDelayed, as the committee can force opt-out

        optInOutState.optOutBlock = uint64(block.number);
        _setOptInOutStateWithOptOutDelay(opKey, optInOutState);
        _setIsOperatorBlocked(opKey, true);

        emit OptOutRequested(moduleId, operatorId, true);
    }

    function getOperatorDelegates(uint24 moduleId, uint64 operatorId)
        external
        view
        returns (Delegate[] memory delegates)
    {
        uint256 opKey = __encOpKey(moduleId, operatorId);
        delegates = _getOperatorDelegatesStorage(opKey);
    }

    function addOperatorDelegate(bytes memory key) external whenNotPaused {
        (uint256 opKey,,) = _checkOptInAndLoadStateByManager(msg.sender);

        /// @dev no checks on delegate key
        _addOperatorDelegate(opKey, key);
        (uint24 moduleId, uint64 operatorId) = __decOpKey(opKey);
        emit OperatorDelegateAdded(moduleId, operatorId, key);
    }

    function delOperatorDelegate(uint256 dIdx) external whenNotPaused {
        (uint256 opKey,,) = _checkOptInAndLoadStateByManager(msg.sender);

        bytes memory key = _getOperatorDelegateStorage(opKey, dIdx).key;

        _delOperatorDelegate(opKey, dIdx);
        (uint24 moduleId, uint64 operatorId) = __decOpKey(opKey);
        emit OperatorDelegateDeleted(moduleId, operatorId, key);
    }

    function getOperatorCommitments(uint24 moduleId, uint64 operatorId)
        external
        view
        returns (Commitment[] memory commitments)
    {
        uint256 opKey = __encOpKey(moduleId, operatorId);
        commitments = _getOperatorCommitmentsStorage(opKey);
    }

    /// @notice Update the operator's keys kr
    /// @dev should be called by the operator manager address
    /// @dev `opt-in` action
    function addOperatorCommitment(uint64 indexStart, uint64 indexEnd, string calldata rpcUrl) external whenNotPaused {
        (uint256 opKey, OptInOutState memory optInOutState, OperatorOptInOutFlags memory flags) =
            _checkOptInAndLoadStateByManager(msg.sender);
        _checkOptInDelayed(flags);

        LidoOperatorCache memory _c;
        (uint24 moduleId, uint64 operatorId) = __decOpKey(opKey);
        _loadLidoNodeOperator(_c, moduleId, operatorId);
        _checkAndAddCommitment(_c, opKey, indexStart, indexEnd, rpcUrl);
        emit OperatorCommitmentAdded(moduleId, operatorId, indexStart, indexEnd, rpcUrl);

        /// @dev update the opt-in delay off block and save state
        _setOptInOutStateWithOptInDelay(opKey, optInOutState);
    }

    /// @notice Delete the operator's commitment (keys kr)
    /// @dev should be called by the operator manager address
    /// @dev `opt-out` action
    function delOperatorCommitment(uint256 cIdx) external whenNotPaused {
        (uint256 opKey, OptInOutState memory optInOutState, OperatorOptInOutFlags memory flags) =
            _checkOptInAndLoadStateByManager(msg.sender);
        _checkOptOutDelayed(flags);

        KeyRange memory kr = _getOperatorCommitmentStorage(opKey, cIdx).keyRange;
        _delOperatorCommitment(opKey, cIdx);
        (uint24 moduleId, uint64 operatorId) = __decOpKey(opKey);
        emit OperatorCommitmentDeleted(moduleId, operatorId, kr.indexStart, kr.indexEnd);

        /// @dev update the opt-out delay off block and save state
        _setOptInOutStateWithOptOutDelay(opKey, optInOutState);
    }

    /// @dev if the new kr just extends existing one - it's considered as an `opt-in` action, otherwise - `opt-out` action
    function updateOperatorCommitment(uint256 cIdx, uint64 indexStart, uint64 indexEnd, string calldata rpcUrl)
        external
        whenNotPaused
    {
        (uint256 opKey, OptInOutState memory optInOutState, OperatorOptInOutFlags memory flags) =
            _checkOptInAndLoadStateByManager(msg.sender);

        bool isExtend = true;
        KeyRange memory kr = _getOperatorCommitmentStorage(opKey, cIdx).keyRange;
        if (indexStart > kr.indexStart || indexEnd < kr.indexEnd) {
            isExtend = false;
        }

        if (isExtend) {
            _checkOptInDelayed(flags);
        } else {
            _checkOptOutDelayed(flags);
        }

        // delete the old commitment
        _delOperatorCommitment(opKey, cIdx);

        // add the new commitment
        LidoOperatorCache memory _c;
        (uint24 moduleId, uint64 operatorId) = __decOpKey(opKey);
        _loadLidoNodeOperator(_c, moduleId, operatorId);
        _checkAndAddCommitment(_c, opKey, indexStart, indexEnd, rpcUrl);
        emit OperatorCommitmentDeleted(moduleId, operatorId, kr.indexStart, kr.indexEnd);
        emit OperatorCommitmentAdded(moduleId, operatorId, indexStart, indexEnd, rpcUrl);

        if (isExtend) {
            /// @dev update the opt-in delay off block and save state
            _setOptInOutStateWithOptInDelay(opKey, optInOutState);
        } else {
            /// @dev update the opt-out delay off block and save state
            _setOptInOutStateWithOptOutDelay(opKey, optInOutState);
        }
    }

    function updateOperatorCommitmentExtraData(uint256 cIdx, string calldata rpcUrl) external whenNotPaused {
        (uint256 opKey,,) = _checkOptInAndLoadStateByManager(msg.sender);

        KeyRange memory kr = _getOperatorCommitmentStorage(opKey, cIdx).keyRange;
        _setOperatorCommitmentRPCUrl(opKey, cIdx, rpcUrl);
        (uint24 moduleId, uint64 operatorId) = __decOpKey(opKey);
        emit OperatorCommitmentAdded(moduleId, operatorId, kr.indexStart, kr.indexEnd, rpcUrl);
    }

    function getOperatorManager(uint24 moduleId, uint64 operatorId) external view returns (address) {
        uint256 opKey = __encOpKey(moduleId, operatorId);
        return _getOperatorManager(opKey);
    }

    /// @notice Update the operator's manager address
    /// @dev should be called by the operator reward address
    function updateOperatorManager(uint24 moduleId, uint64 operatorId, address newManager) external whenNotPaused {
        if (newManager == address(0)) revert ZeroOperatorManagerAddress();

        LidoOperatorCache memory _c;
        /// @dev correctness of moduleId and operatorId are checked inside
        _loadLidoNodeOperator(_c, moduleId, operatorId);

        // check if the caller is the operator's reward address
        if (msg.sender != _c.rewardAddress) {
            revert RewardAddressMismatch();
        }

        // check if the operator is active in Lido module
        if (!_c.isActive) {
            revert OperatorNotActive();
        }

        uint256 opKey = _getOpKeyById(moduleId, operatorId);
        if (_getIsOperatorBlocked(opKey)) {
            revert OperatorBlocked();
        }

        _checkOptInAndLoadState(opKey);

        /// @dev also checks if the proposed manager is already registered for different operator
        _setOperatorManager(opKey, newManager);
        emit OperatorManagerUpdated(moduleId, operatorId, newManager);
    }

    function getOperator(uint24 moduleId, uint64 operatorId)
        external
        view
        returns (address manager, bool isBlocked, bool isEnabled, OptInOutState memory optInOutState)
    {
        uint256 opKey = _getOpKeyById(moduleId, operatorId);
        manager = _getOperatorManager(opKey);
        isBlocked = _getIsOperatorBlocked(opKey);
        optInOutState = _getOperatorOptInOutState(opKey);

        isEnabled = _isOperatorIsEnabledForPreconf(moduleId, operatorId, optInOutState);
    }

    //
    function getOperatorIsEnabledForPreconf(uint24 moduleId, uint64 operatorId) external view returns (bool) {
        uint256 opKey = __encOpKey(moduleId, operatorId);
        OptInOutState memory optInOutState = _getOperatorOptInOutState(opKey);

        return _isOperatorIsEnabledForPreconf(moduleId, operatorId, optInOutState);
    }

    function getOperatorAllowedKeys(uint24 moduleId, uint64 operatorId) external view returns (uint64 allowedKeys) {
        uint256 opKey = __encOpKey(moduleId, operatorId);
        if (_getIsOperatorBlocked(opKey)) {
            return 0;
        }

        // check if the module has max keys limit
        allowedKeys = getModuleOperatorMaxKeys(moduleId);
        if (allowedKeys == 0) {
            return 0;
        }
        // check if the operator is active in Lido module
        LidoOperatorCache memory _c;
        _loadLidoNodeOperator(_c, moduleId, operatorId);
        if (!_c.isActive) {
            return 0;
        }
        // min(operator totalAddedKeys, moduleMaxKeys)
        if (allowedKeys > _c.totalKeys) {
            allowedKeys = _c.totalKeys;
        }

        OperatorOptInOutFlags memory flags = _calcOptInOutFlags(_getOperatorOptInOutState(opKey));
        if (flags.isOptedIn) {
            (uint64 committedKeys,) = _loadCommitmentKeyRanges(opKey);
            // check if the operator has already reached the max keys limit
            if (committedKeys >= allowedKeys) {
                return 0;
            }
            unchecked {
                allowedKeys -= committedKeys;
            }
        }
    }

    function getConfig()
        external
        view
        returns (
            uint64 optInDelayBlocks,
            uint64 optOutDelayBlocks,
            uint64 defaultOperatorMaxKeys,
            uint64 defaultBlockGasLimit
        )
    {
        return _getConfig();
    }

    function getModuleConfig(uint24 moduleId)
        external
        view
        returns (bool isDisabled, uint64 operatorMaxKeys, uint64 blockGasLimit)
    {
        return _getModuleConfig(moduleId);
    }

    function getModuleBlockGasLimit(uint24 moduleId) external view returns (uint64) {
        (,,, uint64 defaultBlockGasLimit) = _getConfig();
        (bool isDisabled,, uint64 blockGasLimit) = _getModuleConfig(moduleId);
        return isDisabled ? 0 : blockGasLimit == 0 ? defaultBlockGasLimit : blockGasLimit;
    }

    function getModuleOperatorMaxKeys(uint24 moduleId) public view returns (uint64) {
        (,, uint64 defaultOperatorMaxKeys,) = _getConfig();
        (bool isDisabled, uint64 operatorMaxKeys,) = _getModuleConfig(moduleId);
        return isDisabled ? 0 : operatorMaxKeys == 0 ? defaultOperatorMaxKeys : operatorMaxKeys;
    }

    function getContractVersion() external view returns (uint64) {
        return _getInitializedVersion();
    }

    function unblockOperator(uint24 moduleId, uint64 operatorId) external onlyRole(COMMITTEE_ROLE) {
        uint256 opKey = _getOpKeyById(moduleId, operatorId);
        bool isBlocked = _getIsOperatorBlocked(opKey);
        if (isBlocked) {
            _setIsOperatorBlocked(opKey, false);
        }
        emit UnblockOperator(moduleId, operatorId);
    }

    /// @notice update min opt-in and opt-out delay durations,
    ///         default operator's max keys for the module and block gas limit
    function setConfig(
        uint64 optInDelayBlocks,
        uint64 optOutDelayBlocks,
        uint64 defaultOperatorMaxKeys,
        uint64 defaultBlockGasLimit
    ) external onlyRole(COMMITTEE_ROLE) {
        _updateConfig(optInDelayBlocks, optOutDelayBlocks, defaultOperatorMaxKeys, defaultBlockGasLimit);
    }

    /// @notice Update Disable/enable state and operator's max keys for the module
    function setModuleConfig(uint24 moduleId, bool isDisabled, uint64 operatorMaxKeys, uint64 blockGasLimit)
        external
        onlyRole(COMMITTEE_ROLE)
    {
        /// @dev check moduleId via staking router
        LidoOperatorCache memory _c;
        _loadLidoModuleData(_c, moduleId);

        _setModuleConfig(moduleId, isDisabled, operatorMaxKeys, blockGasLimit);
        emit ModuleConfigUpdated(moduleId, isDisabled, operatorMaxKeys, blockGasLimit);
    }

    function _updateConfig(
        uint64 optInDelayBlocks,
        uint64 optOutDelayBlocks,
        uint64 defaultOperatorMaxKeys,
        uint64 defaultBlockGasLimit
    ) internal {
        _setConfig(optInDelayBlocks, optOutDelayBlocks, defaultOperatorMaxKeys, defaultBlockGasLimit);
        emit ConfigUpdated(optInDelayBlocks, optOutDelayBlocks, defaultOperatorMaxKeys, defaultBlockGasLimit);
    }

    function _checkAndAddCommitment(
        LidoOperatorCache memory _c,
        uint256 opKey,
        uint64 indexStart,
        uint64 indexEnd,
        string calldata rpcUrl
    ) internal {
        if (indexStart > indexEnd) {
            revert KeyIndexMismatch();
        }

        if (indexEnd >= _c.totalKeys) {
            revert KeyIndexOutOfRange();
        }

        (uint64 committedKeys, KeyRange[] memory ranges) = _loadCommitmentKeyRanges(opKey);

        if (ranges.length >= MAX_COMMITMENTS) {
            revert CommitmentsLimitReached();
        }

        // check for overlapping with existing ranges
        for (uint256 i = 0; i < ranges.length;) {
            // condition for overlapping two ranges [s1,e1] and [s2,e2]:
            // they overlap if s1 <= e2 and s2 <= e1.
            if ((indexStart <= ranges[i].indexEnd) && (ranges[i].indexStart <= indexEnd)) {
                revert KeyIndexOverlapExisting();
            }

            unchecked {
                ++i;
            }
        }

        // new total committed keys
        committedKeys += indexEnd - indexStart + 1;
        _checkModuleParams(_c.moduleId, committedKeys);

        /// @dev no checks on rpcUrl
        _addOperatorCommitment(opKey, indexStart, indexEnd, rpcUrl);
    }

    function _loadCommitmentKeyRanges(uint256 opKey)
        internal
        view
        returns (uint64 committedKeys, KeyRange[] memory ranges)
    {
        Commitment[] storage commitments = _getOperatorCommitmentsStorage(opKey);
        uint256 commitmentsLen = commitments.length;
        uint64 rangeLen;

        ranges = new KeyRange[](commitmentsLen);

        for (uint256 i = 0; i < commitmentsLen;) {
            ranges[i] = commitments[i].keyRange;
            unchecked {
                rangeLen = ranges[i].indexEnd - ranges[i].indexStart + 1;
                ++i;
            }
            committedKeys += rangeLen;
        }
    }

    function _checkOptInAndLoadStateByManager(address manager)
        internal
        view
        returns (uint256 opKey, OptInOutState memory optInOutState, OperatorOptInOutFlags memory flags)
    {
        opKey = _getOpKeyByManager(manager);
        (optInOutState, flags) = _checkOptInAndLoadState(opKey);
    }

    function _checkOptInAndLoadState(uint256 opKey)
        internal
        view
        returns (OptInOutState memory optInOutState, OperatorOptInOutFlags memory flags)
    {
        optInOutState = _getOperatorOptInOutState(opKey);
        flags = _calcOptInOutFlags(optInOutState);

        if (!flags.isOptedIn) {
            revert OperatorOptedOut();
        }
    }

    function _isOperatorIsEnabledForPreconf(uint24 moduleId, uint64 operatorId, OptInOutState memory optInOutState)
        internal
        view
        returns (bool)
    {
        OperatorOptInOutFlags memory flags = _calcOptInOutFlags(optInOutState);
        (bool isModuleDisabled,,) = _getModuleConfig(moduleId);

        LidoOperatorCache memory _c;
        _loadLidoNodeOperator(_c, moduleId, operatorId);

        // operator is enabled:
        // - if it's s opted in
        // - if module not disabled
        // - if operator is active in Lido module
        // - if the contract is not paused
        return flags.isOptedIn && !isModuleDisabled && _c.isActive && !paused();
    }

    function _checkModuleParams(uint24 moduleId, uint64 committedKeys) internal view {
        uint64 maxKeys = getModuleOperatorMaxKeys(moduleId);
        if (maxKeys == 0) {
            revert ModuleDisabled();
        }
        if (committedKeys > maxKeys) {
            revert KeyRangeExceedMaxKeys();
        }
    }

    function _calcOptInOutFlags(OptInOutState memory optInOutState)
        internal
        view
        returns (OperatorOptInOutFlags memory flags)
    {
        bool isOptedOut = optInOutState.optOutBlock > 0; // && blockNumber >= optInOutState.optOutBlock;
        bool isOptedIn = optInOutState.optInBlock > 0 && !isOptedOut;
        // any opt-in action is delayed after any opt-out action is made
        bool isOptInDelayed = _isDelay(optInOutState.optOutBlock);
        // any opt-out action is delayed after any opt-in action is made
        bool isOptOutDelayed = _isDelay(optInOutState.optInBlock);

        return OperatorOptInOutFlags({
            isOptedIn: isOptedIn,
            // isOptedOut: isOptedOut,
            isOptInDelayed: isOptInDelayed,
            isOptOutDelayed: isOptOutDelayed
        });
    }

    /// CACHE

    /// @notice Get the staking router address from LidoLocator
    function _getStakingRouter() internal view returns (IStakingRouter) {
        return IStakingRouter(LIDO_LOCATOR.stakingRouter());
    }

    /// @notice Prepare the cache for the staking module and node operator
    function _loadLidoNodeOperator(LidoOperatorCache memory _c, uint24 moduleId, uint64 operatorId) internal view {
        _loadLidoModuleData(_c, moduleId);
        _loadLidoNodeOperatorData(_c, operatorId);
    }

    function _loadLidoModuleData(LidoOperatorCache memory _c, uint24 moduleId) internal view {
        /// @dev module id validity check is done in the staking router
        StakingModule memory module = _getStakingRouter().getStakingModule(moduleId);

        _c.moduleId = moduleId;
        _c.moduleAddress = module.stakingModuleAddress;
    }

    function _loadLidoNodeOperatorData(LidoOperatorCache memory _c, uint64 operatorId) internal view {
        if (_c.moduleId == 0) {
            revert InvalidModuleId();
        }

        /// @dev check if the operatorId is valid
        uint64 totalOperatorsCount = uint64(IStakingModule(_c.moduleAddress).getNodeOperatorsCount());
        if (operatorId >= totalOperatorsCount) {
            revert InvalidOperatorId();
        }
        _c.operatorId = operatorId;

        /// @dev check for the CSModule type
        bytes32 moduleType = IStakingModule(_c.moduleAddress).getType();
        if (moduleType == CS_MODULE_TYPE) {
            ICSModule module = ICSModule(_c.moduleAddress);
            _c.isActive = module.getNodeOperatorIsActive(operatorId);
            CSMNodeOperator memory operator = module.getNodeOperator(operatorId);
            _c.rewardAddress = operator.rewardAddress;
            _c.totalKeys = operator.totalAddedKeys;
        } else {
            ICuratedModule module = ICuratedModule(_c.moduleAddress);
            (_c.isActive,, _c.rewardAddress,,, _c.totalKeys) = module.getNodeOperator(operatorId, false);
        }
    }

    function _isDelay(uint64 offBlock) internal view returns (bool) {
        return offBlock >= block.number;
    }

    function _checkOptInDelayed(OperatorOptInOutFlags memory flags) internal pure {
        if (flags.isOptInDelayed) {
            revert OptInActionDelayed();
        }
    }

    function _checkOptOutDelayed(OperatorOptInOutFlags memory flags) internal pure {
        if (flags.isOptOutDelayed) {
            revert OptOutActionDelayed();
        }
    }

    function _setOptInOutStateWithOptOutDelay(uint256 opKey, OptInOutState memory state) internal {
        (, uint64 optOutDelayBlocks,,) = _getConfig();
        state.optOutDelayOffBlock = uint64(block.number + optOutDelayBlocks);
        _setOperatorOptInOutState(opKey, state);
    }

    function _setOptInOutStateWithOptInDelay(uint256 opKey, OptInOutState memory state) internal {
        (uint64 optInDelayBlocks,,,) = _getConfig();
        state.optInDelayOffBlock = uint64(block.number + optInDelayBlocks);
        _setOperatorOptInOutState(opKey, state);
    }
}
