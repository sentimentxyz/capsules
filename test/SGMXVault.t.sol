// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {GMXVault} from "../src/gmx/GMXVault.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract GMXVAULTest is Test {

    GMXVault vault;

    address user = makeAddr("user");

    uint fork = vm.createFork(vm.envString("RPC"));

    address constant GMX = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
    address constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant sbfGMX = 0xd2D1162512F927a7e282Ef43a362659E4F2a728F;
    address constant SGMX = 0x908C4D94D34924765f1eDc22A1DD098397c59dD4;

    function setUp() public {
        vm.selectFork(fork);

        vault = new GMXVault(ERC20(GMX), "GMX", "GMX", 0);
    }

    function testDeposit(uint64 amt) public {
        vm.assume(amt > 1e16);
        deal(GMX, user, amt);

        startHoax(user);

        ERC20(GMX).approve(address(vault), type(uint).max);
        uint shares = vault.deposit(amt, user);

        assertEq(vault.balanceOf(user), shares);
        assertEq(0, ERC20(GMX).balanceOf(address(vault)));
        assertEq(ERC20(sbfGMX).balanceOf(address(vault)), amt);
    }

    function testDepositAfterHarvest(uint64 amt, uint64 roll) public {
        testHarvest(amt, roll);
        vm.stopPrank();

        address newUser = makeAddr("newUser");
        deal(GMX, newUser, amt);
        startHoax(newUser);
        ERC20(GMX).approve(address(vault), type(uint).max);
        uint shares = vault.deposit(amt, newUser);

        assertEq(vault.balanceOf(newUser), shares);
        assertEq(0, ERC20(GMX).balanceOf(address(vault)));
        assertGt(ERC20(sbfGMX).balanceOf(address(vault)), uint256(amt) * 2);
        assertEq(ERC20(WETH).balanceOf(address(vault)), 0);
    }

    function testRedeem(uint64 amt) public {
        testDeposit(amt);

        uint assets = vault.redeem(vault.balanceOf(user), user, user);

        assertEq(0, ERC20(GMX).balanceOf(address(vault)));
        assertEq(ERC20(GMX).balanceOf(user), assets);
    }

    function testHarvest(uint64 amt, uint64 roll) public {
        vm.assume(roll > 0);

        testDeposit(amt);

        vm.roll(block.number + roll);
        vm.warp(block.timestamp + roll);
        vault.harvest();

        assertGt(vault.previewRedeem(1e18), 1e18);
        assertEq(0, ERC20(GMX).balanceOf(address(vault)));
        assertEq(0, ERC20(WETH).balanceOf(address(vault)));
        assertGt(vault.totalAssets(), amt);
    }

    function testWithdrawAfterHarvet(uint64 amt, uint64 roll) public {
        testHarvest(amt, roll);

        vault.redeem(vault.balanceOf(user), user, user);

        assertGt(ERC20(GMX).balanceOf(user), amt - vault.reserveShares());
        assertGt(ERC20(sbfGMX).balanceOf(address(vault)), vault.reserveShares());
    }

    function testPreviewRedeemAfterHarvest(uint64 amt, uint64 roll) public {
        testDeposit(amt);

        vm.roll(block.number + roll);
        vm.warp(block.timestamp + roll);

        vault.harvest();

        assertEq(
            vault.previewRedeem(vault.balanceOf(user)),
            vault.redeem(vault.balanceOf(user), user, user)
        );
    }

    function testPreviewRedeem(uint64 amt, uint64 roll) public {
        testDeposit(amt);

        vm.roll(block.number + roll);
        vm.warp(block.timestamp + roll);

        assertEq(
            vault.previewRedeem(vault.balanceOf(user)),
            vault.redeem(vault.balanceOf(user), user, user)
        );
    }

    function testRoundTrip(uint64 amt, uint64 roll) public {
        testDeposit(amt);
        vm.stopPrank();

        vm.roll(block.number + roll);
        vm.warp(block.timestamp + roll);

        address attacker = makeAddr("attacker");
        deal(GMX, attacker, amt);
        startHoax(attacker);
        ERC20(GMX).approve(address(vault), type(uint).max);
        uint shares = vault.deposit(amt, attacker);

        assertLe(vault.redeem(shares, attacker, attacker), amt);
    }
}
