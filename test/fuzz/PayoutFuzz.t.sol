// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../BaseTest.sol";

/// @title PayoutFuzzTest
/// @notice Fuzz tests for payout calculations
contract PayoutFuzzTest is BaseTest {
    /// @notice TC-FZ-001: Fuzz test payout calculation with random bet amounts
    function testFuzz_PayoutCalculation(
        uint256 yesBetAmount,
        uint256 noBetAmount,
        bool yesWins
    ) public {
        // Bound inputs to reasonable ranges
        yesBetAmount = bound(yesBetAmount, 1, usdc(100_000));
        noBetAmount = bound(noBetAmount, 1, usdc(100_000));

        // Mint tokens
        stablecoin.mint(alice, yesBetAmount);
        stablecoin.mint(bob, noBetAmount);

        // Create market
        uint256 marketId = createDefaultMarket();

        // Place bets
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, yesBetAmount);
        placeBet(bob, marketId, PredictionMarket.Outcome.No, noBetAmount);

        // Resolve
        warpToResolution(marketId);
        PredictionMarket.Outcome winningOutcome =
            yesWins ? PredictionMarket.Outcome.Yes : PredictionMarket.Outcome.No;
        resolveMarket(marketId, winningOutcome);

        // Calculate expected payouts
        uint256 aliceExpected;
        uint256 bobExpected;

        if (yesWins) {
            aliceExpected = yesBetAmount + (yesBetAmount * noBetAmount) / yesBetAmount;
            bobExpected = 0;
        } else {
            aliceExpected = 0;
            bobExpected = noBetAmount + (noBetAmount * yesBetAmount) / noBetAmount;
        }

        // Get actual payouts
        uint256 alicePayout = market.calculatePayout(marketId, alice);
        uint256 bobPayout = market.calculatePayout(marketId, bob);

        // Verify
        assertEq(alicePayout, aliceExpected);
        assertEq(bobPayout, bobExpected);

        // Claim and verify balances
        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);
        uint256 bobBalanceBefore = stablecoin.balanceOf(bob);

        claimWinnings(alice, marketId);
        claimWinnings(bob, marketId);

        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore + aliceExpected);
        assertEq(stablecoin.balanceOf(bob), bobBalanceBefore + bobExpected);

        // Invariant: Total payout equals total pool
        assertEq(alicePayout + bobPayout, yesBetAmount + noBetAmount);
    }

    /// @notice TC-FZ-002: Fuzz test with multiple bettors
    function testFuzz_MultipleBettors(
        uint256[3] memory yesBets,
        uint256[3] memory noBets,
        bool yesWins
    ) public {
        // Bound inputs
        for (uint256 i = 0; i < 3; i++) {
            yesBets[i] = bound(yesBets[i], 0, usdc(10_000));
            noBets[i] = bound(noBets[i], 0, usdc(10_000));
        }

        // Ensure at least one bet on each side
        yesBets[0] = yesBets[0] < usdc(1) ? usdc(1) : yesBets[0];
        noBets[0] = noBets[0] < usdc(1) ? usdc(1) : noBets[0];

        // Create bettors
        address[3] memory bettors = [
            makeAddr("bettor1"),
            makeAddr("bettor2"),
            makeAddr("bettor3")
        ];

        // Setup
        uint256 marketId = createDefaultMarket();
        uint256 totalYes;
        uint256 totalNo;

        for (uint256 i = 0; i < 3; i++) {
            if (yesBets[i] > 0) {
                stablecoin.mint(bettors[i], yesBets[i]);
                vm.prank(bettors[i]);
                stablecoin.approve(address(market), type(uint256).max);
                placeBet(bettors[i], marketId, PredictionMarket.Outcome.Yes, yesBets[i]);
                totalYes += yesBets[i];
            }
            if (noBets[i] > 0) {
                stablecoin.mint(bettors[i], noBets[i]);
                vm.prank(bettors[i]);
                stablecoin.approve(address(market), type(uint256).max);
                placeBet(bettors[i], marketId, PredictionMarket.Outcome.No, noBets[i]);
                totalNo += noBets[i];
            }
        }

        // Resolve
        warpToResolution(marketId);
        PredictionMarket.Outcome winningOutcome =
            yesWins ? PredictionMarket.Outcome.Yes : PredictionMarket.Outcome.No;
        resolveMarket(marketId, winningOutcome);

        // Calculate and verify total payout
        uint256 totalPayout;
        for (uint256 i = 0; i < 3; i++) {
            totalPayout += market.calculatePayout(marketId, bettors[i]);
        }

        // Total payout should equal total pool (minus any rounding dust)
        assertApproxEqAbs(totalPayout, totalYes + totalNo, 3);
    }

    /// @notice TC-FZ-003: Fuzz test boundary values
    function testFuzz_BoundaryValues(uint256 amount) public {
        // Test various boundary values
        amount = bound(amount, 1, type(uint128).max);

        // Mint tokens
        stablecoin.mint(alice, amount);
        stablecoin.mint(bob, amount);

        // Create market and place bets
        uint256 marketId = createDefaultMarket();
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, amount);
        placeBet(bob, marketId, PredictionMarket.Outcome.No, amount);

        // Resolve
        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        // Winner gets double
        uint256 payout = market.calculatePayout(marketId, alice);
        assertEq(payout, amount * 2);
    }

    /// @notice Fuzz test cancelled market refunds
    function testFuzz_CancelledRefund(uint256 yesBet, uint256 noBet) public {
        yesBet = bound(yesBet, 1, usdc(100_000));
        noBet = bound(noBet, 0, usdc(100_000));

        stablecoin.mint(alice, yesBet + noBet);

        uint256 marketId = createDefaultMarket();
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, yesBet);
        if (noBet > 0) {
            placeBet(alice, marketId, PredictionMarket.Outcome.No, noBet);
        }

        warpToResolution(marketId);
        cancelMarket(marketId);

        uint256 payout = market.calculatePayout(marketId, alice);
        assertEq(payout, yesBet + noBet);
    }

    /// @notice TC-FZ-004: Fuzz test invalid market IDs
    function testFuzz_InvalidMarketId(uint256 marketId) public {
        // Any ID > marketCounter or 0 should revert
        vm.assume(marketId == 0 || marketId > market.marketCounter());

        vm.expectRevert(PredictionMarket.InvalidMarket.selector);
        market.getMarket(marketId);
    }

    /// @notice TC-FZ-005: Fuzz test timestamps
    function testFuzz_ResolutionTime(uint256 futureOffset) public {
        // Offset must be positive
        futureOffset = bound(futureOffset, 1, 365 days);

        uint256 resolutionTime = block.timestamp + futureOffset;

        vm.prank(alice);
        uint256 marketId = market.createMarket("Test?", resolutionTime, 0);

        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(m.resolutionTime, resolutionTime);
    }
}
