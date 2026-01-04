// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../BaseTest.sol";

/// @title ViewFunctionsTest
/// @notice Unit tests for view functions
contract ViewFunctionsTest is BaseTest {
    uint256 public marketId;

    function setUp() public override {
        super.setUp();
        marketId = createDefaultMarket();
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(50));
    }

    // ============ getMarket Tests ============

    /// @notice TC-VF-001: Get Market Details
    function test_GetMarket_Success() public view {
        PredictionMarket.Market memory m = market.getMarket(marketId);

        assertEq(m.id, marketId);
        assertEq(m.question, "Will Bitcoin reach $100k?");
        assertEq(uint8(m.state), uint8(PredictionMarket.MarketState.Active));
        assertEq(m.yesPool, usdc(100));
        assertEq(m.noPool, usdc(50));
        assertEq(m.creator, alice);
    }

    /// @notice Test getMarket with invalid ID
    function test_GetMarket_RevertIf_InvalidId() public {
        vm.expectRevert(PredictionMarket.InvalidMarket.selector);
        market.getMarket(999);
    }

    /// @notice Test getMarket with ID 0
    function test_GetMarket_RevertIf_ZeroId() public {
        vm.expectRevert(PredictionMarket.InvalidMarket.selector);
        market.getMarket(0);
    }

    // ============ getUserPosition Tests ============

    /// @notice TC-VF-002: Get User Position
    function test_GetUserPosition_Success() public view {
        PredictionMarket.UserPosition memory pos = market.getUserPosition(marketId, alice);

        assertEq(pos.yesBet, usdc(100));
        assertEq(pos.noBet, 0);
        assertFalse(pos.claimed);
    }

    /// @notice Test getUserPosition with no position
    function test_GetUserPosition_NoPosition() public view {
        PredictionMarket.UserPosition memory pos = market.getUserPosition(marketId, charlie);

        assertEq(pos.yesBet, 0);
        assertEq(pos.noBet, 0);
        assertFalse(pos.claimed);
    }

    // ============ calculatePayout Tests ============

    /// @notice TC-VF-003: Calculate Payout (Winning Side)
    function test_CalculatePayout_WinningSide() public {
        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        uint256 payout = market.calculatePayout(marketId, alice);

        // 100 + (100/100) * 50 = 150
        assertEq(payout, usdc(150));
    }

    /// @notice TC-VF-004: Calculate Payout (Losing Side)
    function test_CalculatePayout_LosingSide() public {
        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        uint256 payout = market.calculatePayout(marketId, bob);

        assertEq(payout, 0);
    }

    /// @notice TC-VF-005: Calculate Payout (Cancelled)
    function test_CalculatePayout_Cancelled() public {
        warpToResolution(marketId);
        cancelMarket(marketId);

        uint256 alicePayout = market.calculatePayout(marketId, alice);
        uint256 bobPayout = market.calculatePayout(marketId, bob);

        assertEq(alicePayout, usdc(100));
        assertEq(bobPayout, usdc(50));
    }

    /// @notice Test calculatePayout on active market
    function test_CalculatePayout_ActiveMarket() public view {
        uint256 payout = market.calculatePayout(marketId, alice);
        assertEq(payout, 0);
    }

    /// @notice Test calculatePayout after claiming
    function test_CalculatePayout_AfterClaim() public {
        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);
        claimWinnings(alice, marketId);

        uint256 payout = market.calculatePayout(marketId, alice);
        assertEq(payout, 0);
    }

    /// @notice Test calculatePayout with no position
    function test_CalculatePayout_NoPosition() public {
        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        uint256 payout = market.calculatePayout(marketId, charlie);
        assertEq(payout, 0);
    }

    // ============ getConfig Tests ============

    /// @notice Test getConfig
    function test_GetConfig() public view {
        PredictionMarket.Config memory cfg = market.getConfig();

        assertEq(cfg.admin, admin);
        assertEq(cfg.feeRecipient, feeRecipient);
        assertEq(cfg.maxFeePercentage, MAX_FEE_PERCENTAGE);
        assertFalse(cfg.paused);
    }

    // ============ getMarketCount Tests ============

    /// @notice Test getMarketCount
    function test_GetMarketCount() public view {
        assertEq(market.getMarketCount(), 1);
    }

    /// @notice Test getMarketCount after multiple markets
    function test_GetMarketCount_Multiple() public {
        createMarket("Question 2?", block.timestamp + ONE_WEEK, 0);
        createMarket("Question 3?", block.timestamp + ONE_WEEK, 0);

        assertEq(market.getMarketCount(), 3);
    }
}
