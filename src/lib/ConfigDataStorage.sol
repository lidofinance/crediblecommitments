// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

struct OptInOutConfig {
    // minimum duration of the opt-in period in blocks
    uint64 optInMinDurationBlocks;
    // delay in blocks before the operator can opt-in again after opt-out
    uint64 optOutDelayDurationBlocks;
}

library ConfigDataStorage {
    // keccak256(abi.encode(uint256(keccak256("lido.cccp.ConfigData")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ConfigDataStorageLocation =
        0x88bc7ecea4f5ca5d158a1e193fef3c7c2a04ebbd97df9f73242140d0d88e0600;

    struct ConfigData {
        OptInOutConfig optInOut;
    }

    function _getConfigStorage() private pure returns (ConfigData storage $) {
        assembly {
            $.slot := ConfigDataStorageLocation
        }
    }

    function _getConfigOptInOut() internal view returns (OptInOutConfig memory) {
        return _getConfigStorage().optInOut;
    }

    // function _getConfigOptInOutVars() internal view returns (uint64 optInMinDurationBlocks, uint64 optOutDelayDurationBlocks) {
    //     OptInOutConfig memory optInOutCfg = _getConfigOptInOut();
    //     return (optInOutCfg.optInMinDurationBlocks, optInOutCfg.optOutDelayDurationBlocks);
    // }

    function _setConfigOptInOut(OptInOutConfig memory config) internal {
        _getConfigStorage().optInOut = config;
    }

    // function _setConfigOptInOutVars(uint64 optInMinDurationBlocks, uint64 optOutDelayDurationBlocks) internal {
    //     _setConfigOptInOut(
    //         OptInOutConfig({optInMinDurationBlocks: optInMinDurationBlocks, optOutDelayDurationBlocks: optOutDelayDurationBlocks})
    //     );
    // }
}
