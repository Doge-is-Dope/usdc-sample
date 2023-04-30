// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/IProxy.sol";
import "../src/FiatTokenV3_2.sol";

contract MyContractTest is Test {
    address constant USDC_PROXY = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDC_ADMIN = 0x807a96288A1A408dBC13DE2b1d087d10356395d2;
    address constant USDC_V2_IMPL = 0xa2327a938Febf5FEC13baCFb16Ae10EcBc4cbDCF; // FiatTokenV2
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    uint256 mainnetFork;
    /// @dev Add MAINNET_RPC_URL="..." in .env file

    IProxy proxy; // AdminUpgradeabilityProxy
    FiatTokenV3 token; // FiatTokenV3
    address admin; // Admin of AdminUpgradeabilityProxy
    address user1; // Random user
    address user2; // Random user

    function setUp() public {
        // Create a fork and select it
        mainnetFork = vm.createSelectFork(MAINNET_RPC_URL);

        // Set up proxy and owner
        proxy = IProxy(USDC_PROXY);
        admin = address(USDC_ADMIN);

        // Deploy V3_2
        token = new FiatTokenV3();

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

        // Assert the implementation is tokenV4 after upgrade
        vm.expectEmit(false, false, false, true);
        emit Upgraded(address(token));
        proxy.upgradeTo(address(token));
        assertEq(proxy.implementation(), address(token));

        vm.stopPrank();
    }

    /// @dev
    function testWhitelist() public {
        vm.startPrank(admin);
        proxy.upgradeTo(address(token));
        token = FiatTokenV3(proxy.implementation());
        token.addToWhiteList(admin); // admin shall be whitelisted
        token.addToWhiteList(user1);
        assertEq(token.isWhiteListed(user1), true); // user1 is whitelisted
        assertEq(token.isWhiteListed(user2), false); // user2 is not whitelisted

        token.mint(user1, 10 ether); // admin can mint to user1 because admin is whitelisted
        assertEq(token.balanceOf(user1), 10 ether);
        vm.stopPrank();

        // whitelisted user1 can transfer to user2
        vm.startPrank(user1);
        token.transfer(user2, 1 ether);
        assertEq(token.balanceOf(user2), 1 ether);
        vm.stopPrank();

        // non-whitelisted user2 can NOT transfer to user1
        vm.startPrank(user2);
        vm.expectRevert("not whitelisted");
        token.transfer(user1, 0.5 ether);
        vm.stopPrank();

        // whitelisted user1 can mint tokens
        vm.startPrank(user1);
        token.mint(user1, 100 ether);
        assertEq(token.balanceOf(user1), 109 ether); // 10 - 1 + 100 = 109
        vm.stopPrank();

        // non-whitelisted user2 can NOT mint tokens
        vm.startPrank(user2);
        vm.expectRevert("not whitelisted");
        token.mint(user2, 100 ether);
        assertEq(token.balanceOf(user2), 1 ether);
        vm.stopPrank();
    }
}
