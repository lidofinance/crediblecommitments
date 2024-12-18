// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/Curator.sol";
import "./mocks/MockStakingRouter.sol";

contract CuratorTest is Test {
    Curator public curator;

    address public owner = address(0x123);
    address public user = address(0x456);
    MockStakingRouter public mockRouter;

    function setUp() public {
        // Развёртываем мок
        mockRouter = new MockStakingRouter();

        // Устанавливаем владельца как msg.sender
        vm.prank(owner);
        curator = new Curator(address(mockRouter));

        // Настраиваем моковые данные
        MockStakingRouter.MockStakingModule memory module = MockStakingRouter.MockStakingModule({
            id: 1,
            stakingModuleAddress: address(0xABC),
            stakingModuleFee: 10,
            treasuryFee: 5,
            stakeShareLimit: 50,
            status: 1,
            name: "Mock Module",
            lastDepositAt: uint64(block.timestamp),
            lastDepositBlock: block.number,
            exitedValidatorsCount: 0,
            priorityExitShareThreshold: 10,
            maxDepositsPerBlock: 100,
            minDepositBlockDistance: 1
        });

        mockRouter.setStakingModule(1, module);
    }

    function testSetMaxValidatorsForStakingModule_Success() public {
        // Убедимся, что владелец может установить лимит
        vm.prank(owner);
        curator.setMaxValidatorsForStakingModule(1, 100);

        uint256 limit = curator.maxValidatorsForModule(1);
        assertEq(limit, 100, "Max validators not set correctly");
    }

    function testSetMaxValidatorsForStakingModule_Fail_NotOwner() public {
        // Попробуем установить лимит не владельцем
        vm.prank(user);
        vm.expectRevert("Not the owner");
        curator.setMaxValidatorsForStakingModule(1, 100);
    }

    function testOptIn_Success() public {
        // Установим лимит валидаторов
        vm.prank(owner);
        curator.setMaxValidatorsForStakingModule(1, 10);

        // Попробуем вызвать optIn с корректным диапазоном ключей
        vm.prank(user);
        curator.optIn(address(0xabc), address(0xdef), 1, 1, 1, 10);

        // Проверяем, что оператор зарегистрирован
        (address eoa, uint256 moduleId, uint256 operatorId, uint256 keysRangeStart, uint256 keysRangeEnd) =
            curator.operators(address(0xabc));

        assertEq(eoa, address(0xdef), "EOA not set correctly");
        assertEq(moduleId, 1, "Module ID not set correctly");
        assertEq(operatorId, 1, "Operator ID not set correctly");
        assertEq(keysRangeStart, 1, "Keys range start not set correctly");
        assertEq(keysRangeEnd, 10, "Keys range end not set correctly");
    }

    function testOptIn_Fail_ExceedValidatorLimit() public {
        // Установим лимит валидаторов
        vm.prank(owner);
        curator.setMaxValidatorsForStakingModule(1, 10);

        // Попробуем вызвать optIn с диапазоном ключей, превышающим лимит
        vm.prank(user);
        vm.expectRevert("Validator limit exceeded for module");
        curator.optIn(address(0xabc), address(0xdef), 1, 1, 1, 20);
    }
}
