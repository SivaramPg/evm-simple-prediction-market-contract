// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../BaseTest.sol";

/// @title MarketLifecycleTest
/// @notice Integration tests for complete market lifecycle
contract MarketLifecycleTest is BaseTest {
    // ============ Full Lifecycle Tests ============

    /// @notice TC-IT-001: Complete Market Flow (YES Wins)
    function test_FullLifecycle_YesWins() public {
        // 1. Create market
        uint256 marketId = createDefaultMarket();

        // 2. Users place bets
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(charlie, marketId, PredictionMarket.Outcome.No, usdc(100));

        // Verify pools
        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(m.yesPool, usdc(200));
        assertEq(m.noPool, usdc(100));

        // 3. Warp to resolution time
        warpToResolution(marketId);

        // 4. Resolve market
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        // 5. Users claim winnings
        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);
        uint256 bobBalanceBefore = stablecoin.balanceOf(bob);
        uint256 charlieBalanceBefore = stablecoin.balanceOf(charlie);

        claimWinnings(alice, marketId);
        claimWinnings(bob, marketId);
        claimWinnings(charlie, marketId);

        // Verify payouts
        // Alice: 100 + (100/200) * 100 = 150
        // Bob: 100 + (100/200) * 100 = 150
        // Charlie: 0 (lost)
        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore + usdc(150));
        assertEq(stablecoin.balanceOf(bob), bobBalanceBefore + usdc(150));
        assertEq(stablecoin.balanceOf(charlie), charlieBalanceBefore);

        // Verify all claimed
        assertTrue(market.getUserPosition(marketId, alice).claimed);
        assertTrue(market.getUserPosition(marketId, bob).claimed);
        assertTrue(market.getUserPosition(marketId, charlie).claimed);
    }

    /// @notice TC-IT-002: Complete Market Flow (NO Wins)
    function test_FullLifecycle_NoWins() public {
        uint256 marketId = createDefaultMarket();

        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(50));
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(100));
        placeBet(charlie, marketId, PredictionMarket.Outcome.No, usdc(100));

        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.No);

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);
        uint256 bobBalanceBefore = stablecoin.balanceOf(bob);
        uint256 charlieBalanceBefore = stablecoin.balanceOf(charlie);

        claimWinnings(alice, marketId);
        claimWinnings(bob, marketId);
        claimWinnings(charlie, marketId);

        // Alice: 0 (lost)
        // Bob: 100 + (100/200) * 50 = 125
        // Charlie: 100 + (100/200) * 50 = 125
        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore);
        assertEq(stablecoin.balanceOf(bob), bobBalanceBefore + usdc(125));
        assertEq(stablecoin.balanceOf(charlie), charlieBalanceBefore + usdc(125));
    }

    /// @notice TC-IT-003: Complete Market Flow (Cancelled)
    function test_FullLifecycle_Cancelled() public {
        uint256 marketId = createDefaultMarket();

        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId, PredictionMarket.Outcome.Yes, usdc(50));
        // No opposition

        warpToResolution(marketId);

        // Try to resolve - should fail
        vm.prank(admin);
        vm.expectRevert(PredictionMarket.NoOpposition.selector);
        market.resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        // Cancel instead
        cancelMarket(marketId);

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);
        uint256 bobBalanceBefore = stablecoin.balanceOf(bob);

        claimWinnings(alice, marketId);
        claimWinnings(bob, marketId);

        // Full refunds
        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore + usdc(100));
        assertEq(stablecoin.balanceOf(bob), bobBalanceBefore + usdc(50));
    }

    /// @notice TC-IT-004: Proportional Payout Distribution
    function test_ProportionalPayout() public {
        uint256 marketId = createDefaultMarket();

        // A: 100 YES, B: 50 YES, C: 25 YES, D: 100 NO
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId, PredictionMarket.Outcome.Yes, usdc(50));
        placeBet(charlie, marketId, PredictionMarket.Outcome.Yes, usdc(25));

        address dave = makeAddr("dave");
        stablecoin.mint(dave, usdc(1000));
        vm.prank(dave);
        stablecoin.approve(address(market), type(uint256).max);
        placeBet(dave, marketId, PredictionMarket.Outcome.No, usdc(100));

        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        // YES pool = 175, NO pool = 100
        // Alice: 100 + (100/175) * 100 = 100 + 57.14 = 157 (truncated)
        // Bob: 50 + (50/175) * 100 = 50 + 28.57 = 78 (truncated)
        // Charlie: 25 + (25/175) * 100 = 25 + 14.28 = 39 (truncated)

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);
        uint256 bobBalanceBefore = stablecoin.balanceOf(bob);
        uint256 charlieBalanceBefore = stablecoin.balanceOf(charlie);

        claimWinnings(alice, marketId);
        claimWinnings(bob, marketId);
        claimWinnings(charlie, marketId);

        // Check with some tolerance for rounding
        assertApproxEqAbs(
            stablecoin.balanceOf(alice) - aliceBalanceBefore,
            usdc(100) + (usdc(100) * usdc(100)) / usdc(175),
            1
        );
        assertApproxEqAbs(
            stablecoin.balanceOf(bob) - bobBalanceBefore,
            usdc(50) + (usdc(50) * usdc(100)) / usdc(175),
            1
        );
        assertApproxEqAbs(
            stablecoin.balanceOf(charlie) - charlieBalanceBefore,
            usdc(25) + (usdc(25) * usdc(100)) / usdc(175),
            1
        );
    }

    /// @notice TC-IT-005: Single Bettor Wins All
    function test_SingleBettorWinsAll() public {
        uint256 marketId = createDefaultMarket();

        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(50));
        placeBet(charlie, marketId, PredictionMarket.Outcome.No, usdc(50));

        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);

        claimWinnings(alice, marketId);

        // Alice gets: 100 + 100 = 200 (entire losing pool)
        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore + usdc(200));
    }

    /// @notice TC-IT-007: Equal Pool Sizes
    function test_EqualPoolSizes() public {
        uint256 marketId = createDefaultMarket();

        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(100));

        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);

        claimWinnings(alice, marketId);

        // Alice gets: 100 + 100 = 200
        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore + usdc(200));
    }

    /// @notice TC-IT-008: Very Small Winning Pool
    function test_SmallWinningPool() public {
        uint256 marketId = createDefaultMarket();

        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(1));
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(1000));

        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);

        claimWinnings(alice, marketId);

        // Alice gets: 1 + 1000 = 1001
        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore + usdc(1001));
    }

    /// @notice TC-IT-009: Very Small Losing Pool
    function test_SmallLosingPool() public {
        uint256 marketId = createDefaultMarket();

        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(1000));
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(1));

        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);

        claimWinnings(alice, marketId);

        // Alice gets: 1000 + 1 = 1001
        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore + usdc(1001));
    }

    /// @notice TC-IT-010: Hedged Position On Resolved Market
    function test_HedgedPositionResolved() public {
        uint256 marketId = createDefaultMarket();

        // Alice bets both sides
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(alice, marketId, PredictionMarket.Outcome.No, usdc(50));
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(100));

        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);

        claimWinnings(alice, marketId);

        // YES pool = 100, NO pool = 150
        // Alice's YES bet wins: 100 + (100/100) * 150 = 250
        // Alice's NO bet is lost
        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore + usdc(250));
    }

    /// @notice TC-IT-011: Multiple Markets Same User
    function test_MultipleMarketsSameUser() public {
        uint256 marketId1 = createMarket("Question 1?", block.timestamp + ONE_WEEK, 0);
        uint256 marketId2 = createMarket("Question 2?", block.timestamp + ONE_WEEK, 0);

        placeBet(alice, marketId1, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId1, PredictionMarket.Outcome.No, usdc(100));

        placeBet(alice, marketId2, PredictionMarket.Outcome.No, usdc(100));
        placeBet(bob, marketId2, PredictionMarket.Outcome.Yes, usdc(100));

        vm.warp(block.timestamp + ONE_WEEK + 1);

        resolveMarket(marketId1, PredictionMarket.Outcome.Yes);
        resolveMarket(marketId2, PredictionMarket.Outcome.No);

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);

        claimWinnings(alice, marketId1);
        claimWinnings(alice, marketId2);

        // Market 1: Alice wins 100 + 100 = 200
        // Market 2: Alice wins 100 + 100 = 200
        // Total: 400
        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore + usdc(400));
    }

    /// @notice Test contract balance remains zero after all claims
    function test_ContractBalanceZeroAfterClaims() public {
        uint256 marketId = createDefaultMarket();

        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(100));

        assertEq(stablecoin.balanceOf(address(market)), usdc(200));

        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        claimWinnings(alice, marketId);
        claimWinnings(bob, marketId);

        // All funds distributed
        assertEq(stablecoin.balanceOf(address(market)), 0);
    }
}
