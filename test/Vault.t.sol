// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "../lib/forge-std/src/Test.sol";
import {MockERC20} from "../lib/solmate/src/test/utils/mocks/MockERC20.sol";

import {Vault} from "../src/Vault.sol";
import {VaultEvents} from "../src/interfaces/VaultEvents.sol";
import {YieldStrategy} from "../src/interfaces/YieldStrategy.sol";
import {MockPool, MockYieldStrategy, MockRevertingYieldStrategy} from "./mocks/MockYieldStrategy.sol";

contract VaultTest is Test, VaultEvents {
    MockERC20 underlyingAsset = new MockERC20("Mock", "MCK", 18);
    MockPool pool = new MockPool(underlyingAsset);
    YieldStrategy strategy = new MockYieldStrategy(address(pool), address(underlyingAsset));
    YieldStrategy newStrategy = new MockYieldStrategy(address(pool), address(underlyingAsset));
    YieldStrategy problemStrategy = new MockRevertingYieldStrategy(address(pool), address(underlyingAsset));

    address owner;
    address alice;

    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");

        underlyingAsset.mint(alice, 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        SET STRATEGY
    //////////////////////////////////////////////////////////////*/

    function testCanSetStrategyIfOwner() public {
        vm.startPrank(owner);
        Vault vault = new Vault(underlyingAsset, strategy);

        vm.expectCall(address(strategy), abi.encodeCall(strategy.withdrawAll, ()), 1);
        vm.expectCall(
            address(newStrategy), abi.encodeCall(strategy.deposit, (underlyingAsset.balanceOf(address(pool)))), 1
        );

        vm.expectEmit(true, false, false, true, address(vault));
        emit StrategyUpdate(newStrategy);

        vault.setStrategy(newStrategy);
        vm.stopPrank();

        YieldStrategy activeStrategy = vault.activeStrategy();
        assertEq(address(activeStrategy), address(newStrategy));
    }

    function testRevertIfSetStrategyByNonOwner() public {
        vm.startPrank(owner);
        Vault vault = new Vault(underlyingAsset, strategy);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert();
        vault.setStrategy(newStrategy);
        vm.stopPrank();
    }

    function testRevertIfSetStrategyAndStrategyReverts() public {
        vm.startPrank(owner);
        Vault vault = new Vault(underlyingAsset, problemStrategy);
        vm.expectRevert();
        vault.setStrategy(newStrategy);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT
    //////////////////////////////////////////////////////////////*/

    function testCanDeposit() public {
        vm.startPrank(owner);
        Vault vault = new Vault(underlyingAsset, strategy);
        vm.stopPrank();

        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1 ether);

        vm.expectCall(
            address(underlyingAsset), abi.encodeCall(underlyingAsset.approve, (address(strategy), 1 ether)), 1
        );
        vm.expectCall(address(strategy), abi.encodeCall(strategy.deposit, (1 ether)), 1);

        vm.expectEmit(true, true, false, true, address(vault));
        emit Deposit(address(alice), strategy, 1 ether);

        vault.deposit(1 ether, alice);
        vm.stopPrank();

        assertEq(underlyingAsset.balanceOf(address(alice)), 0);
        assertEq(underlyingAsset.balanceOf(address(pool)), 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function testCanWithdraw() public {
        vm.startPrank(owner);
        Vault vault = new Vault(underlyingAsset, strategy);
        vm.stopPrank();

        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1 ether);
        vault.deposit(1 ether, alice);

        /**
         * @dev not sure where balanceOf is being called, either in MockERC20 or ERC20
         *
         * ├─ [1659] Vault::withdraw(1000000000000000000 [1e18], alice: [0x328809Bc894f92807417D2dAD6b7C998c1aFdac6], alice: [0x328809Bc894f92807417D2dAD6b7C998c1aFdac6]) 
         * │   ├─ [542] MockERC20::balanceOf(Vault: [0x88F59F8826af5e695B13cA934d6c7999875A9EeA]) [staticcall]
         * │   │   └─ ← 0
         * │   └─ ← "EvmError: Revert"
         * └─ ← "EvmError: Revert"
         */
        underlyingAsset.mint(address(vault), 1 ether);

        vm.expectCall(address(strategy), abi.encodeCall(strategy.withdraw, (1 ether, 1 ether, 1 ether)), 1);

        vm.expectEmit(true, true, false, true, address(vault));
        emit Withdrawal(address(alice), strategy, 1 ether, 1 ether, 1 ether);

        vault.withdraw(1 ether, alice, alice);
        vm.stopPrank();

        assertEq(underlyingAsset.balanceOf(address(alice)), 1 ether);
        assertEq(underlyingAsset.balanceOf(address(pool)), 0);
    }
}
