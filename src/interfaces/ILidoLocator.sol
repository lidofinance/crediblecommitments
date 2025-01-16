// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

interface ILidoLocator {
    function stakingRouter() external view returns (address payable);
}
