// SPDX-FileCopyrightText: 2024 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

import {CommonBase, Vm} from "forge-std/Base.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/// @author madlabman
contract Utilities is CommonBase {
    bytes32 internal seed = keccak256("seed sEed seEd");

    function nextAddress() internal returns (address) {
        bytes32 buf = keccak256(abi.encodePacked(seed));
        address a = address(uint160(uint256(buf)));
        seed = buf;
        return a;
    }

    function nextAddress(string memory label) internal returns (address) {
        address a = nextAddress();
        vm.label(a, label);
        return a;
    }

    function expectRoleRevert(address account, bytes32 neededRole) internal {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, account, neededRole)
        );
    }
}
