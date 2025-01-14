// SPDX-FileCopyrightText: 2025 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.28;

interface ILidoLocator {
    function burner() external view returns (address);
    function coreComponents() external view returns (address, address, address, address, address, address);
    function lido() external view returns (address);
    function stakingRouter() external view returns (address payable);
    function treasury() external view returns (address);
}
