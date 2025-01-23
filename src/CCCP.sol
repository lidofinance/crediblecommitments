// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlEnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {CCCPOperatorStatesStorage} from "./lib/CCCPOperatorStatesStorage.sol";
import {CCCPConfigStorage} from "./lib/CCCPConfigStorage.sol";
import {ICCCP} from "./interfaces/ICCCP.sol";

import {ILidoLocator} from "./interfaces/ILidoLocator.sol";
import {StakingModule, IStakingRouter} from "./interfaces/IStakingRouter.sol";
import {IStakingModule} from "./interfaces/IStakingModule.sol";
import {CSMNodeOperator, ICSModule} from "./interfaces/ICSModule.sol";
import {ICuratedModule} from "./interfaces/ICuratedModule.sol";

/**
 * @title CCCP
 * @notice CredibleCommitmentCurationProvider contract
 */
contract CCCP is
    ICCCP,
    Initializable,
    CCCPConfigStorage,
    CCCPOperatorStatesStorage,
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
        bool isOptedOut;
        bool optInAllowed;
        bool optOutAllowed;
    }

    bytes32 public constant COMMITTEE_ROLE = keccak256("COMMITTEE_ROLE");
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    bytes32 public constant RESUME_ROLE = keccak256("RESUME_ROLE");

    ILidoLocator public immutable LIDO_LOCATOR;
    // CSModule type, used for the operator's state retrieval
    bytes32 internal immutable CS_MODULE_TYPE;

    event OptInSucceeded(uint256 indexed moduleId, uint256 indexed operatorId, address manager);
    event OptOutRequested(uint256 indexed moduleId, uint256 indexed operatorId, bool isForced);
    event ResetForcedOptOut(uint256 indexed moduleId, uint256 indexed operatorId);

    event KeysRangeUpdated(uint256 indexed moduleId, uint256 indexed operatorId, uint256 indexStart, uint256 indexEnd);
    event OperatorManagerUpdated(uint256 indexed moduleId, uint256 indexed operatorId, address manager);
    event RPCUrlUpdated(uint256 indexed moduleId, uint256 indexed operatorId, string rpcURL);
    event ConfigUpdated(
        uint256 optInMinDurationBlocks,
        uint256 optOutDelayDurationBlocks,
        uint256 defaultOperatorMaxValidators,
        uint256 defaultBlockGasLimit
    );
    event ModuleConfigUpdated(uint256 indexed moduleId, uint256 operatorMaxValidators, bool isDisabled);

    error RewardAddressMismatch();
    error OperatorNotActive();
    error ModuleDisabled();
    error OperatorAlreadyRegistered();
    error OperatorOptInNotAllowed();
    error OperatorOptOutNotAllowed();
    error KeyIndexOutOfRange();
    error KeysRangeExceedMaxValidators();
    error KeyIndexMismatch();
    error InvalidOperatorId();
    error InvalidModuleId();
    error ZeroCommitteeAddress();
    error ZeroOperatorManagerAddress();
    error ZeroLocatorAddress();

    constructor(address lidoLocator, bytes32 csModuleType) {
        if (lidoLocator == address(0)) revert ZeroLocatorAddress();
        LIDO_LOCATOR = ILidoLocator(lidoLocator);
        CS_MODULE_TYPE = csModuleType;

        _disableInitializers();
    }

    function initialize(
        address committeeAddress,
        uint64 optInMinDurationBlocks,
        uint64 optOutDelayDurationBlocks,
        uint64 defaultOperatorMaxValidators,
        uint64 defaultBlockGasLimit
    ) external initializer {
        if (committeeAddress == address(0)) revert ZeroCommitteeAddress();

        __Pausable_init();
        __AccessControlEnumerable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, committeeAddress);
        _grantRole(COMMITTEE_ROLE, committeeAddress);
        _grantRole(PAUSE_ROLE, committeeAddress);
        _grantRole(RESUME_ROLE, committeeAddress);

        _updateConfig(
            optInMinDurationBlocks, optOutDelayDurationBlocks, defaultOperatorMaxValidators, defaultBlockGasLimit
        );
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
        uint64 newKeyIndexRangeStart,
        uint64 newKeyIndexRangeEnd,
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

        // check if the operator is already has the state
        OptInOutState memory optInOutState = _getOperatorOptInOutState(opKey);
        OperatorOptInOutFlags memory flags = _calcOptInOutFlags(optInOutState);
        if (flags.isOptedIn) {
            revert OperatorAlreadyRegistered();
        } else if (!flags.optInAllowed) {
            revert OperatorOptInNotAllowed();
        }

        // save operator state
        /// @dev also checks if the proposed manager is already registered for different operator
        _setOperatorManager(opKey, manager);
        emit OperatorManagerUpdated(moduleId, operatorId, manager);

        _setOperatorOptInOutState(
            opKey, OptInOutState({optInBlock: uint64(block.number), optOutBlock: 0, isOptOutForced: false})
        );
        _checkAndUpdateKeysRange(_c, opKey, newKeyIndexRangeStart, newKeyIndexRangeEnd);

        /// @dev no checks on rpcUrl, so it can be rewritten on repeated opt-in
        _setOperatorExtraData(opKey, ExtraData({rpcURL: rpcURL}));
        emit RPCUrlUpdated(moduleId, operatorId, rpcURL);

        emit OptInSucceeded(moduleId, operatorId, manager);
    }

    /// @notice Opt-out operator on behalf of the operator manager
    /// @dev should be called by the operator manager address
    function optOut() external whenNotPaused {
        uint256 opKey = _getOpKeyByManager(msg.sender);
        OptInOutState memory optInOutState = _getOperatorOptInOutState(opKey);
        OperatorOptInOutFlags memory flags = _calcOptInOutFlags(optInOutState);
        if (!flags.isOptedIn) {
            revert OperatorNotActive();
        } else if (!flags.optOutAllowed) {
            revert OperatorOptOutNotAllowed();
        }

        optInOutState.optOutBlock = uint64(block.number);
        _setOperatorOptInOutState(opKey, optInOutState);

        (uint24 moduleId, uint64 operatorId) = __decOpKey(opKey);
        emit OptOutRequested(moduleId, operatorId, false);
    }

    /// @notice Opt-out operator on behalf of the committee
    function optOut(uint24 moduleId, uint64 operatorId) external onlyRole(COMMITTEE_ROLE) {
        uint256 opKey = _getOpKeyById(moduleId, operatorId);

        OptInOutState memory optInOutState = _getOperatorOptInOutState(opKey);
        OperatorOptInOutFlags memory flags = _calcOptInOutFlags(optInOutState);
        if (!flags.isOptedIn) {
            revert OperatorNotActive();
        }
        /// @dev ignore optOutAllowed, as the committee can force opt-out

        optInOutState.optOutBlock = uint64(block.number);
        optInOutState.isOptOutForced = true;
        _setOperatorOptInOutState(opKey, optInOutState);

        emit OptOutRequested(moduleId, operatorId, true);
    }

    /// @notice Update the operator's keys range
    /// @dev should be called by the operator manager address
    function updateKeysRange(uint64 newKeyIndexRangeStart, uint64 newKeyIndexRangeEnd) external whenNotPaused {
        uint256 opKey = _getOpKeyByManager(msg.sender);
        OperatorOptInOutFlags memory flags = _calcOptInOutFlags(_getOperatorOptInOutState(opKey));
        if (!flags.isOptedIn) {
            revert OperatorNotActive();
        }

        KeysRange memory keysRange = _getOperatorKeysRange(opKey);
        if (
            newKeyIndexRangeStart > keysRange.indexStart || newKeyIndexRangeEnd < keysRange.indexEnd
                || (newKeyIndexRangeStart == keysRange.indexStart && newKeyIndexRangeEnd == keysRange.indexEnd)
        ) {
            revert KeyIndexMismatch();
        }
        LidoOperatorCache memory _c;
        (uint24 moduleId, uint64 operatorId) = __decOpKey(opKey);
        _loadLidoNodeOperator(_c, moduleId, operatorId);
        _checkAndUpdateKeysRange(_c, opKey, newKeyIndexRangeStart, newKeyIndexRangeEnd);
    }

    /// @notice Update the operator's manager address
    /// @dev should be called by the operator reward address
    function updateManager(uint24 moduleId, uint64 operatorId, address newManager) external whenNotPaused {
        if (newManager == address(0)) revert ZeroOperatorManagerAddress();

        LidoOperatorCache memory _c;
        /// @dev correctness of moduleId and operatorId are checked inside
        _loadLidoNodeOperator(_c, moduleId, operatorId);

        // check if the caller is the operator's reward address
        if (msg.sender != _c.rewardAddress) {
            revert RewardAddressMismatch();
        }

        /// @dev also checks if the proposed manager is already registered for different operator
        _setOperatorManager(__encOpKey(moduleId, operatorId), newManager);
        emit OperatorManagerUpdated(moduleId, operatorId, newManager);
    }

    function getOperator(address manager)
        external
        view
        returns (uint24 moduleId, uint64 operatorId, bool isEnabled, OperatorState memory state)
    {
        uint256 opKey = _getOpKeyByManager(manager);
        return _getOperator(opKey);
    }

    function getOperator(uint24 _moduleId, uint64 _operatorId)
        external
        view
        returns (uint24 moduleId, uint64 operatorId, bool isEnabled, OperatorState memory state)
    {
        uint256 opKey = _getOpKeyById(_moduleId, _operatorId);
        return _getOperator(opKey);
    }

    function getConfig()
        external
        view
        returns (
            uint64 optInMinDurationBlocks,
            uint64 optOutDelayDurationBlocks,
            uint64 defaultOperatorMaxValidators,
            uint64 defaultBlockGasLimit
        )
    {
        return _getConfig();
    }

    function getContractVersion() external view returns (uint64) {
        return _getInitializedVersion();
    }

    function resetForcedOptOut(uint24 moduleId, uint64 operatorId) external onlyRole(COMMITTEE_ROLE) {
        uint256 opKey = _getOpKeyById(moduleId, operatorId);
        OptInOutState memory optInOutState = _getOperatorOptInOutState(opKey);
        if (optInOutState.isOptOutForced) {
            optInOutState.isOptOutForced = false;
            _setOperatorOptInOutState(opKey, optInOutState);
        }
        emit ResetForcedOptOut(moduleId, operatorId);
    }

    /// @notice update min opt-in and opt-out delay durations,
    ///         default operator's max validators for the module and block gas limit
    function setConfig(
        uint64 optInMinDurationBlocks,
        uint64 optOutDelayDurationBlocks,
        uint64 defaultOperatorMaxValidators,
        uint64 defaultBlockGasLimit
    ) external onlyRole(COMMITTEE_ROLE) {
        _updateConfig(
            optInMinDurationBlocks, optOutDelayDurationBlocks, defaultOperatorMaxValidators, defaultBlockGasLimit
        );
    }

    /// @notice Update Disable/enable state and operator's max validators for the module
    function setModuleConfig(uint24 moduleId, bool isDisabled, uint64 operatorMaxValidators)
        external
        onlyRole(COMMITTEE_ROLE)
    {
        /// @dev check moduleId via staking router
        LidoOperatorCache memory _c;
        _loadLidoModuleData(_c, moduleId);

        _setModuleConfig(moduleId, operatorMaxValidators, isDisabled);
        emit ModuleConfigUpdated(moduleId, operatorMaxValidators, isDisabled);
    }

    function _updateConfig(
        uint64 optInMinDurationBlocks,
        uint64 optOutDelayDurationBlocks,
        uint64 defaultOperatorMaxValidators,
        uint64 defaultBlockGasLimit
    ) internal {
        _setConfig(
            optInMinDurationBlocks, optOutDelayDurationBlocks, defaultOperatorMaxValidators, defaultBlockGasLimit
        );
        emit ConfigUpdated(
            optInMinDurationBlocks, optOutDelayDurationBlocks, defaultOperatorMaxValidators, defaultBlockGasLimit
        );
    }

    function _checkAndUpdateKeysRange(
        LidoOperatorCache memory _c,
        uint256 opKey,
        uint64 newKeyIndexRangeStart,
        uint64 newKeyIndexRangeEnd
    ) internal {
        _checkKeysRangeIsValid(_c.totalKeys, newKeyIndexRangeStart, newKeyIndexRangeEnd);
        _checkModuleParams(_c.moduleId, newKeyIndexRangeStart, newKeyIndexRangeEnd);

        // save operator state
        _setOperatorKeysRange(opKey, newKeyIndexRangeStart, newKeyIndexRangeEnd);
        emit KeysRangeUpdated(_c.moduleId, _c.operatorId, newKeyIndexRangeStart, newKeyIndexRangeEnd);
    }

    function _getOperator(uint256 opKey)
        internal
        view
        returns (uint24 moduleId, uint64 operatorId, bool isEnabled, OperatorState memory state)
    {
        LidoOperatorCache memory _c;
        (moduleId, operatorId) = __decOpKey(opKey);
        _loadLidoNodeOperator(_c, moduleId, operatorId);
        state = _getOperatorState(opKey);
        OperatorOptInOutFlags memory flags = _calcOptInOutFlags(state.optInOutState);
        (, bool isDisabled) = _getModuleConfig(_c.moduleId);

        // operator is enabled:
        // - if it's s opted in
        // - if module not disabled
        // - if operator is active in Lido module
        // - if the contract is not paused
        isEnabled = flags.isOptedIn && !isDisabled && _c.isActive && !paused();

        return (_c.moduleId, _c.operatorId, isEnabled, state);
    }

    function _checkModuleParams(uint24 moduleId, uint64 startIndex, uint64 endIndex) internal view {
        (,, uint64 defaultOperatorMaxValidators,) = _getConfig();
        (uint64 moduleMaxValidators, bool isDisabled) = _getModuleConfig(moduleId);
        if (isDisabled) {
            revert ModuleDisabled();
        }
        uint64 totalKeys = endIndex - startIndex + 1;
        uint64 maxValidators = moduleMaxValidators == 0 ? defaultOperatorMaxValidators : moduleMaxValidators;

        if (totalKeys > maxValidators) {
            revert KeysRangeExceedMaxValidators();
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

    function _calcOptInOutFlags(OptInOutState memory optInOutState)
        internal
        view
        returns (OperatorOptInOutFlags memory flags)
    {
        uint64 blockNumber = uint64(block.number);
        (uint64 optInMinDurationBlocks, uint64 optOutDelayDurationBlocks,,) = _getConfig();

        bool isOptedOut =
            optInOutState.optOutBlock > 0 && optInOutState.optOutBlock + optOutDelayDurationBlocks < blockNumber;
        bool isOptedIn = optInOutState.optInBlock > 0 && !isOptedOut;
        bool optInAllowed = !isOptedIn && !optInOutState.isOptOutForced;
        bool optOutAllowed = isOptedIn && optInOutState.optInBlock + optInMinDurationBlocks < blockNumber;

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
}
