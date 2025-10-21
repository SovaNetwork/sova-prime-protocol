// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {SovaBTC} from "../src/token/SovaBtc.sol";

contract SovaBtcTest is Test {
    SovaBTC public token;

    address public owner = address(1);
    address public mintManager = address(2);
    address public burnManager = address(3);
    address public alice = address(4);
    address public bob = address(5);

    event AddedToBlackList(address indexed user);
    event RemovedFromBlackList(address indexed user);
    event DestroyedBlackFunds(address indexed user, uint256 amount);
    event RolesUpdated(address indexed user, uint256 indexed roles);

    function setUp() public {
        token = new SovaBTC(owner, mintManager, burnManager);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Deployment() public view {
        assertEq(token.owner(), owner);
        assertTrue(token.hasAllRoles(mintManager, token.MINT_ROLE()));
        assertTrue(token.hasAllRoles(burnManager, token.BURN_ROLE()));
        assertEq(token.name(), "Sova Bitcoin V1");
        assertEq(token.symbol(), "sovabtc");
        assertEq(token.decimals(), 8);
    }

    function test_RevertWhen_DeployWithZeroOwner() public {
        vm.expectRevert(SovaBTC.ZeroAddress.selector);
        new SovaBTC(address(0), mintManager, burnManager);
    }

    function test_RevertWhen_DeployWithZeroMintManager() public {
        vm.expectRevert(SovaBTC.ZeroAddress.selector);
        new SovaBTC(owner, address(0), burnManager);
    }

    function test_RevertWhen_DeployWithZeroBurnManager() public {
        vm.expectRevert(SovaBTC.ZeroAddress.selector);
        new SovaBTC(owner, mintManager, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        ROLE MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GrantMintRole() public {
        address newManager = address(10);
        uint256 mintRole = token.MINT_ROLE();

        vm.prank(owner);
        token.grantRoles(newManager, mintRole);

        assertTrue(token.hasAllRoles(newManager, mintRole));
    }

    function test_RevokeMintRole() public {
        uint256 mintRole = token.MINT_ROLE();

        vm.prank(owner);
        token.revokeRoles(mintManager, mintRole);

        assertFalse(token.hasAllRoles(mintManager, mintRole));
    }

    function test_RevertWhen_NonOwnerGrantsRole() public {
        address newManager = address(10);
        uint256 mintRole = token.MINT_ROLE();

        vm.prank(alice);
        vm.expectRevert();
        token.grantRoles(newManager, mintRole);
    }

    function test_GrantBurnRole() public {
        address newManager = address(11);
        uint256 burnRole = token.BURN_ROLE();

        vm.prank(owner);
        token.grantRoles(newManager, burnRole);

        assertTrue(token.hasAllRoles(newManager, burnRole));
    }

    function test_RevokeBurnRole() public {
        uint256 burnRole = token.BURN_ROLE();

        vm.prank(owner);
        token.revokeRoles(burnManager, burnRole);

        assertFalse(token.hasAllRoles(burnManager, burnRole));
    }

    /*//////////////////////////////////////////////////////////////
                        MINT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Mint() public {
        uint256 amount = 1000 * 10 ** 8; // 1000 BTC

        vm.prank(mintManager);
        token.mint(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), amount);
    }

    function test_RevertWhen_NonMintManagerMints() public {
        uint256 amount = 1000 * 10 ** 8;

        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, amount);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        uint256 amount = 1000 * 10 ** 8;

        vm.prank(mintManager);
        vm.expectRevert(SovaBTC.ZeroAddress.selector);
        token.mint(address(0), amount);
    }

    function test_RevertWhen_MintToBlacklistedAddress() public {
        uint256 amount = 1000 * 10 ** 8;

        vm.prank(owner);
        token.addBlackList(alice);

        vm.prank(mintManager);
        vm.expectRevert(abi.encodeWithSelector(SovaBTC.BlacklistedAddress.selector, alice));
        token.mint(alice, amount);
    }

    function test_MintMaxAmount() public {
        uint256 maxAmount = token.MAX_MINT_AMOUNT();

        vm.prank(mintManager);
        token.mint(alice, maxAmount);

        assertEq(token.balanceOf(alice), maxAmount);
        assertEq(token.totalSupply(), maxAmount);
    }

    function test_RevertWhen_MintExceedsMaximum() public {
        uint256 maxAmount = token.MAX_MINT_AMOUNT();
        uint256 excessAmount = maxAmount + 1;

        vm.prank(mintManager);
        vm.expectRevert(abi.encodeWithSelector(SovaBTC.MintAmountExceedsMaximum.selector, excessAmount, maxAmount));
        token.mint(alice, excessAmount);
    }

    function test_MintMultipleTimesUnderMax() public {
        uint256 amount = 500 * 10 ** 8; // 500 BTC

        vm.startPrank(mintManager);
        token.mint(alice, amount);
        token.mint(alice, amount);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), amount * 2);
        assertEq(token.totalSupply(), amount * 2);
    }

    /*//////////////////////////////////////////////////////////////
                        BURN TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Burn() public {
        uint256 mintAmount = 1000 * 10 ** 8;
        uint256 burnAmount = 300 * 10 ** 8;

        vm.prank(mintManager);
        token.mint(burnManager, mintAmount);

        vm.prank(burnManager);
        token.burn(burnAmount);

        assertEq(token.balanceOf(burnManager), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }

    function test_RevertWhen_NonBurnManagerBurns() public {
        uint256 amount = 300 * 10 ** 8;

        vm.prank(alice);
        vm.expectRevert();
        token.burn(amount);
    }

    /*//////////////////////////////////////////////////////////////
                        BLACKLIST TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AddBlackList() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit AddedToBlackList(alice);
        token.addBlackList(alice);

        assertTrue(token.isBlacklisted(alice));
    }

    function test_RevertWhen_NonOwnerAddsBlackList() public {
        vm.prank(alice);
        vm.expectRevert();
        token.addBlackList(bob);
    }

    function test_RevertWhen_AddingZeroAddressToBlackList() public {
        vm.prank(owner);
        vm.expectRevert(SovaBTC.ZeroAddress.selector);
        token.addBlackList(address(0));
    }

    function test_RevertWhen_AddingAlreadyBlacklistedAddress() public {
        vm.prank(owner);
        token.addBlackList(alice);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(SovaBTC.BlacklistedAddress.selector, alice));
        token.addBlackList(alice);
    }

    function test_RemoveBlackList() public {
        vm.prank(owner);
        token.addBlackList(alice);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit RemovedFromBlackList(alice);
        token.removeBlackList(alice);

        assertFalse(token.isBlacklisted(alice));
    }

    function test_RevertWhen_NonOwnerRemovesBlackList() public {
        vm.prank(owner);
        token.addBlackList(alice);

        vm.prank(bob);
        vm.expectRevert();
        token.removeBlackList(alice);
    }

    function test_RevertWhen_RemovingNonBlacklistedAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(SovaBTC.NotBlacklisted.selector, alice));
        token.removeBlackList(alice);
    }

    function test_DestroyBlackFunds() public {
        uint256 amount = 1000 * 10 ** 8;

        vm.prank(mintManager);
        token.mint(alice, amount);

        vm.prank(owner);
        token.addBlackList(alice);

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit DestroyedBlackFunds(alice, amount);
        token.destroyBlackFunds(alice);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), 0);
    }

    function test_DestroyBlackFunds_WithZeroBalance() public {
        vm.prank(owner);
        token.addBlackList(alice);

        vm.prank(owner);
        token.destroyBlackFunds(alice);

        assertEq(token.balanceOf(alice), 0);
    }

    function test_RevertWhen_NonOwnerDestroysBlackFunds() public {
        vm.prank(owner);
        token.addBlackList(alice);

        vm.prank(bob);
        vm.expectRevert();
        token.destroyBlackFunds(alice);
    }

    function test_RevertWhen_DestroyingNonBlacklistedFunds() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(SovaBTC.NotBlacklisted.selector, alice));
        token.destroyBlackFunds(alice);
    }

    /*//////////////////////////////////////////////////////////////
                        TRANSFER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Transfer() public {
        uint256 amount = 1000 * 10 ** 8;

        vm.prank(mintManager);
        token.mint(alice, amount);

        vm.prank(alice);
        token.transfer(bob, 300 * 10 ** 8);

        assertEq(token.balanceOf(alice), 700 * 10 ** 8);
        assertEq(token.balanceOf(bob), 300 * 10 ** 8);
    }

    function test_RevertWhen_BlacklistedAddressTransfers() public {
        uint256 amount = 1000 * 10 ** 8;

        vm.prank(mintManager);
        token.mint(alice, amount);

        vm.prank(owner);
        token.addBlackList(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SovaBTC.BlacklistedAddress.selector, alice));
        token.transfer(bob, 300 * 10 ** 8);
    }

    function test_RevertWhen_TransferringToBlacklistedAddress() public {
        uint256 amount = 1000 * 10 ** 8;

        vm.prank(mintManager);
        token.mint(alice, amount);

        vm.prank(owner);
        token.addBlackList(bob);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(SovaBTC.BlacklistedAddress.selector, bob));
        token.transfer(bob, 300 * 10 ** 8);
    }

    function test_TransferAfterBlacklistRemoval() public {
        uint256 amount = 1000 * 10 ** 8;

        vm.prank(mintManager);
        token.mint(alice, amount);

        vm.prank(owner);
        token.addBlackList(alice);

        vm.prank(owner);
        token.removeBlackList(alice);

        vm.prank(alice);
        token.transfer(bob, 300 * 10 ** 8);

        assertEq(token.balanceOf(alice), 700 * 10 ** 8);
        assertEq(token.balanceOf(bob), 300 * 10 ** 8);
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Mint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(!token.isBlacklisted(to));
        vm.assume(amount > 0 && amount <= token.MAX_MINT_AMOUNT());

        vm.prank(mintManager);
        token.mint(to, amount);

        assertEq(token.balanceOf(to), amount);
    }

    function testFuzz_Burn(uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(mintAmount > 0 && mintAmount <= token.MAX_MINT_AMOUNT());
        vm.assume(burnAmount <= mintAmount);

        vm.prank(mintManager);
        token.mint(burnManager, mintAmount);

        vm.prank(burnManager);
        token.burn(burnAmount);

        assertEq(token.balanceOf(burnManager), mintAmount - burnAmount);
    }

    function testFuzz_Transfer(uint256 mintAmount, uint256 transferAmount) public {
        vm.assume(mintAmount > 0 && mintAmount <= token.MAX_MINT_AMOUNT());
        vm.assume(transferAmount <= mintAmount);

        vm.prank(mintManager);
        token.mint(alice, mintAmount);

        vm.prank(alice);
        token.transfer(bob, transferAmount);

        assertEq(token.balanceOf(alice), mintAmount - transferAmount);
        assertEq(token.balanceOf(bob), transferAmount);
    }
}
