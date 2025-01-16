// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

import {ILidoLocator} from "../../../src/interfaces/ILidoLocator.sol";

contract LidoLocatorMock is ILidoLocator {
    address public sr;

    constructor(address _sr) {
        sr = _sr;
    }

    function stakingRouter() external view returns (address payable) {
        return payable(sr);
    }
}
