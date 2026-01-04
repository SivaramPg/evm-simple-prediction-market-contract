// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../BaseTest.sol";

/// @title BettingTest
/// @notice Unit tests for betting functionality
contract BettingTest is BaseTest {
    uint256 public marketId;

    function setUp() public override {
        super.setUp();
        marketId = createDefaultMarket();
    }

    // ============ Success Cases ============

    /// @notice TC-BT-001: Successful YES Bet
    function test_PlaceBet_YesSuccess() public {
        uint256 amount = usdc(100);
        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);

        vm.expectEmit(true, true, true, true);
        emit BetPlaced(
            marketId,
            alice,
            PredictionMarket.Outcome.Yes,
            amount,
            block.timestamp
        );

        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, amount);

        // Check balances
        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore - amount);
        assertEq(stablecoin.balanceOf(address(market)), amount);

        // Check market state
        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(m.yesPool, amount);
        assertEq(m.noPool, 0);

        // Check user position
        PredictionMarket.UserPosition memory pos = market.getUserPosition(marketId, alice);
        assertEq(pos.yesBet, amount);
        assertEq(pos.noBet, 0);
        assertEq(pos.claimed, false);
    }

    /// @notice TC-BT-002: Successful NO Bet
    function test_PlaceBet_NoSuccess() public {
        uint256 amount = usdc(50);

        placeBet(bob, marketId, PredictionMarket.Outcome.No, amount);

        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(m.yesPool, 0);
        assertEq(m.noPool, amount);

        PredictionMarket.UserPosition memory pos = market.getUserPosition(marketId, bob);
        assertEq(pos.yesBet, 0);
        assertEq(pos.noBet, amount);
    }

    /// @notice TC-BT-003: Multiple Bets Same Side
    function test_PlaceBet_MultipleSameSide() public {
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(50));

        PredictionMarket.UserPosition memory pos = market.getUserPosition(marketId, alice);
        assertEq(pos.yesBet, usdc(150));
        assertEq(pos.noBet, 0);

        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(m.yesPool, usdc(150));
    }

    /// @notice TC-BT-004: Hedged Bets (Both Sides)
    function test_PlaceBet_HedgedBothSides() public {
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(alice, marketId, PredictionMarket.Outcome.No, usdc(50));

        PredictionMarket.UserPosition memory pos = market.getUserPosition(marketId, alice);
        assertEq(pos.yesBet, usdc(100));
        assertEq(pos.noBet, usdc(50));

        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(m.yesPool, usdc(100));
        assertEq(m.noPool, usdc(50));
    }

    /// @notice Test multiple users betting
    function test_PlaceBet_MultipleUsers() public {
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId, PredictionMarket.Outcome.Yes, usdc(50));
        placeBet(charlie, marketId, PredictionMarket.Outcome.No, usdc(75));

        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(m.yesPool, usdc(150));
        assertEq(m.noPool, usdc(75));
    }

    // ============ Failure Cases ============

    /// @notice TC-BT-005: Zero Amount Bet
    function test_PlaceBet_RevertIf_ZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.ZeroAmount.selector);
        market.placeBet(marketId, PredictionMarket.Outcome.Yes, 0);
    }

    /// @notice TC-BT-006: Invalid Outcome
    function test_PlaceBet_RevertIf_InvalidOutcome() public {
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.InvalidOutcome.selector);
        market.placeBet(marketId, PredictionMarket.Outcome.None, usdc(100));
    }

    /// @notice TC-BT-007: Bet On Non-Existent Market
    function test_PlaceBet_RevertIf_InvalidMarket() public {
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.InvalidMarket.selector);
        market.placeBet(999, PredictionMarket.Outcome.Yes, usdc(100));
    }

    /// @notice TC-BT-008: Bet On Resolved Market
    function test_PlaceBet_RevertIf_MarketResolved() public {
        // Setup: place bets and resolve
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(50));
        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        vm.prank(charlie);
        vm.expectRevert(PredictionMarket.MarketNotActive.selector);
        market.placeBet(marketId, PredictionMarket.Outcome.Yes, usdc(100));
    }

    /// @notice TC-BT-009: Bet On Cancelled Market
    function test_PlaceBet_RevertIf_MarketCancelled() public {
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        warpToResolution(marketId);
        cancelMarket(marketId);

        vm.prank(bob);
        vm.expectRevert(PredictionMarket.MarketNotActive.selector);
        market.placeBet(marketId, PredictionMarket.Outcome.Yes, usdc(100));
    }

    /// @notice TC-BT-010: Bet After Resolution Time
    function test_PlaceBet_RevertIf_MarketExpired() public {
        warpToResolution(marketId);

        vm.prank(alice);
        vm.expectRevert(PredictionMarket.MarketExpired.selector);
        market.placeBet(marketId, PredictionMarket.Outcome.Yes, usdc(100));
    }

    /// @notice TC-BT-011: Insufficient Balance
    function test_PlaceBet_RevertIf_InsufficientBalance() public {
        address poorUser = makeAddr("poorUser");
        vm.prank(poorUser);
        stablecoin.approve(address(market), type(uint256).max);

        vm.prank(poorUser);
        vm.expectRevert(PredictionMarket.InsufficientBalance.selector);
        market.placeBet(marketId, PredictionMarket.Outcome.Yes, usdc(100));
    }

    /// @notice TC-BT-012: Insufficient Allowance
    function test_PlaceBet_RevertIf_InsufficientAllowance() public {
        address user = makeAddr("user");
        stablecoin.mint(user, usdc(100));
        // Don't approve

        vm.prank(user);
        vm.expectRevert(PredictionMarket.InsufficientAllowance.selector);
        market.placeBet(marketId, PredictionMarket.Outcome.Yes, usdc(100));
    }

    /// @notice TC-BT-013: Bet When Paused
    function test_PlaceBet_RevertIf_Paused() public {
        vm.prank(admin);
        market.pause();

        vm.prank(alice);
        vm.expectRevert(PredictionMarket.Paused.selector);
        market.placeBet(marketId, PredictionMarket.Outcome.Yes, usdc(100));
    }
}
