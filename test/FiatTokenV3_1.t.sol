// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/IProxy.sol";
import "../src/FiatTokenV3_1.sol";

contract TestFiatTokenV3_1 is Test {
    address constant USDC_PROXY = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDC_ADMIN = 0x807a96288A1A408dBC13DE2b1d087d10356395d2;
    address constant USDC_V2_IMPL = 0xa2327a938Febf5FEC13baCFb16Ae10EcBc4cbDCF; // FiatTokenV2
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    uint256 mainnetFork;
    /// @dev Add MAINNET_RPC_URL="..." in .env file

    IProxy proxy; // AdminUpgradeabilityProxy
    FiatTokenV3 tokenV3; // FiatTokenV3
    address admin; // Admin of AdminUpgradeabilityProxy
    address user1; // Random user
    address user2; // Random user

    function setUp() public {
        // Create a fork and select it
        mainnetFork = vm.createSelectFork(MAINNET_RPC_URL);

        // Set up proxy and owner
        proxy = IProxy(USDC_PROXY);
        admin = address(USDC_ADMIN);

        // Deploy V3
        tokenV3 = new FiatTokenV3();

        // Create random users
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
    }

    /// @dev Test if the fork is set up correctly
    function testFork() public {
        assertEq(vm.activeFork(), mainnetFork);
    }

    /// @dev Check if the admin is correct
    function testAdmin() public {
        vm.startPrank(admin);
        assertEq(proxy.admin(), admin);
        vm.stopPrank();
    }

    event Upgraded(address implementation);

    /// @dev Check if the contract is upgradable
    function testUpgrade() public {
        vm.startPrank(admin);
        // Assert the implementation can not be set to address(0x0)
        vm.expectRevert(
            "Cannot set a proxy implementation to a non-contract address"
        );
        proxy.upgradeTo(address(0x0));

        // Assert the implementation is tokenV2
        assertEq(proxy.implementation(), address(USDC_V2_IMPL));

        // Assert the implementation is tokenV3 after upgrade
        vm.expectEmit(false, false, false, true);
        emit Upgraded(address(tokenV3));
        proxy.upgradeTo(address(tokenV3));
        assertEq(proxy.implementation(), address(tokenV3));

        vm.stopPrank();
    }

    /// @dev
    function testWhitelist() public {
        vm.startPrank(admin);
        proxy.upgradeTo(address(tokenV3));
        tokenV3 = FiatTokenV3(proxy.implementation());
        tokenV3.addToWhiteList(admin); // admin shall be whitelisted
        tokenV3.addToWhiteList(user1);
        assertEq(tokenV3.isWhiteListed(user1), true); // user1 is whitelisted
        assertEq(tokenV3.isWhiteListed(user2), false); // user2 is not whitelisted

        tokenV3.newMint(user1, 10 ether); // admin can mint to user1 because admin is whitelisted
        assertEq(tokenV3.balanceOf(user1), 10 ether);
        vm.stopPrank();

        // whitelisted user1 can transfer to user2
        vm.startPrank(user1);
        tokenV3.newTransfer(user2, 1 ether);
        assertEq(tokenV3.balanceOf(user2), 1 ether);
        vm.stopPrank();

        // non-whitelisted user2 can NOT transfer to user1
        vm.startPrank(user2);
        vm.expectRevert("not whitelisted");
        tokenV3.newTransfer(user1, 0.5 ether);
        vm.stopPrank();

        // whitelisted user1 can mint tokens
        vm.startPrank(user1);
        tokenV3.newMint(user1, 100 ether);
        assertEq(tokenV3.balanceOf(user1), 109 ether); // 10 - 1 + 100 = 109
        vm.stopPrank();

        // non-whitelisted user2 can NOT mint tokens
        vm.startPrank(user2);
        vm.expectRevert("not whitelisted");
        tokenV3.newMint(user2, 100 ether);
        assertEq(tokenV3.balanceOf(user2), 1 ether);
        vm.stopPrank();

        // Remove user1 from whitelist
        vm.startPrank(user1);
        tokenV3.removeFromWhitelist(user1);
        assertEq(tokenV3.isWhiteListed(user1), false); // user1 is not whitelisted
        vm.expectRevert("not whitelisted");
        tokenV3.newMint(user2, 100 ether);
        vm.stopPrank();
    }
}
