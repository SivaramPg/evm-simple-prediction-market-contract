// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../BaseTest.sol";

/// @title ClaimingTest
/// @notice Unit tests for claiming winnings functionality
contract ClaimingTest is BaseTest {
    uint256 public marketId;

    function setUp() public override {
        super.setUp();
        marketId = createDefaultMarket();
    }

    // ============ Success Cases ============

    /// @notice TC-CL-001: Successful Claim (Winning Side)
    function test_ClaimWinnings_WinningSide() public {
        // Setup: Alice bets 100 YES, Bob bets 50 NO, YES wins
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(50));
        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);

        // Expected payout: 100 + (100/100) * 50 = 150
        uint256 expectedPayout = usdc(150);

        vm.expectEmit(true, true, true, true);
        emit WinningsClaimed(marketId, alice, expectedPayout, block.timestamp);

        claimWinnings(alice, marketId);

        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore + expectedPayout);

        PredictionMarket.UserPosition memory pos = market.getUserPosition(marketId, alice);
        assertTrue(pos.claimed);
    }

    /// @notice TC-CL-002: Successful Claim (Losing Side) - Zero Payout
    function test_ClaimWinnings_LosingSide() public {
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(50));
        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        uint256 bobBalanceBefore = stablecoin.balanceOf(bob);

        claimWinnings(bob, marketId);

        // Bob loses, gets 0
        assertEq(stablecoin.balanceOf(bob), bobBalanceBefore);

        PredictionMarket.UserPosition memory pos = market.getUserPosition(marketId, bob);
        assertTrue(pos.claimed);
    }

    /// @notice TC-CL-003: Successful Claim (Cancelled Market)
    function test_ClaimWinnings_CancelledMarket() public {
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(alice, marketId, PredictionMarket.Outcome.No, usdc(50));
        warpToResolution(marketId);
        cancelMarket(marketId);

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);

        // Expected: Full refund of 100 + 50 = 150
        uint256 expectedPayout = usdc(150);

        claimWinnings(alice, marketId);

        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore + expectedPayout);
    }

    /// @notice TC-CL-004: Hedged Position on Cancelled Market
    function test_ClaimWinnings_HedgedCancelled() public {
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(alice, marketId, PredictionMarket.Outcome.No, usdc(50));
        warpToResolution(marketId);
        cancelMarket(marketId);

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);

        claimWinnings(alice, marketId);

        // Gets back both bets
        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore + usdc(150));
    }

    /// @notice Test proportional payout calculation
    function test_ClaimWinnings_ProportionalPayout() public {
        // Alice: 100 YES, Bob: 100 YES, Charlie: 100 NO
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(charlie, marketId, PredictionMarket.Outcome.No, usdc(100));
        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);
        uint256 bobBalanceBefore = stablecoin.balanceOf(bob);

        // Each YES bettor gets: 100 + (100/200) * 100 = 150
        claimWinnings(alice, marketId);
        claimWinnings(bob, marketId);

        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore + usdc(150));
        assertEq(stablecoin.balanceOf(bob), bobBalanceBefore + usdc(150));
    }

    /// @notice Test single bettor wins entire losing pool
    function test_ClaimWinnings_SingleWinnerTakesAll() public {
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(50));
        placeBet(charlie, marketId, PredictionMarket.Outcome.No, usdc(50));
        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);

        // Alice gets: 100 + 100 = 200 (entire losing pool)
        claimWinnings(alice, marketId);

        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore + usdc(200));
    }

    // ============ Failure Cases ============

    /// @notice TC-CL-005: Claim On Active Market
    function test_ClaimWinnings_RevertIf_MarketActive() public {
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));

        vm.prank(alice);
        vm.expectRevert(PredictionMarket.MarketNotFinalized.selector);
        market.claimWinnings(marketId);
    }

    /// @notice TC-CL-006: Double Claim
    function test_ClaimWinnings_RevertIf_AlreadyClaimed() public {
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(50));
        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        claimWinnings(alice, marketId);

        vm.prank(alice);
        vm.expectRevert(PredictionMarket.AlreadyClaimed.selector);
        market.claimWinnings(marketId);
    }

    /// @notice TC-CL-007: Claim With No Position
    function test_ClaimWinnings_RevertIf_NoPosition() public {
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(50));
        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        vm.prank(charlie);
        vm.expectRevert(PredictionMarket.NoPosition.selector);
        market.claimWinnings(marketId);
    }

    /// @notice TC-CL-008: Claim On Non-Existent Market
    function test_ClaimWinnings_RevertIf_InvalidMarket() public {
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.InvalidMarket.selector);
        market.claimWinnings(999);
    }

    /// @notice Test batch claim
    function test_ClaimMultipleWinnings() public {
        // Create second market
        uint256 marketId2 = createMarket("Test 2?", block.timestamp + ONE_WEEK, 0);

        // Alice bets on both markets
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(50));
        placeBet(alice, marketId2, PredictionMarket.Outcome.No, usdc(100));
        placeBet(bob, marketId2, PredictionMarket.Outcome.Yes, usdc(50));

        // Warp and resolve both
        vm.warp(block.timestamp + ONE_WEEK + 1);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);
        resolveMarket(marketId2, PredictionMarket.Outcome.No);

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);

        // Claim both at once
        uint256[] memory marketIds = new uint256[](2);
        marketIds[0] = marketId;
        marketIds[1] = marketId2;

        vm.prank(alice);
        market.claimMultipleWinnings(marketIds);

        // Market 1: 100 + (100/100) * 50 = 150
        // Market 2: 100 + (100/100) * 50 = 150
        // Total: 300
        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore + usdc(300));
    }
}
