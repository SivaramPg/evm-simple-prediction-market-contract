// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../BaseTest.sol";

/// @title ResolutionTest
/// @notice Unit tests for market resolution functionality
contract ResolutionTest is BaseTest {
    uint256 public marketId;

    function setUp() public override {
        super.setUp();
        marketId = createDefaultMarket();

        // Setup: place bets on both sides
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(200));
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(100));
    }

    // ============ Success Cases ============

    /// @notice TC-RS-001: Successful Resolution (YES Wins)
    function test_ResolveMarket_YesWins() public {
        warpToResolution(marketId);

        vm.expectEmit(true, true, true, true);
        emit MarketResolved(
            marketId,
            PredictionMarket.Outcome.Yes,
            usdc(200),
            usdc(100),
            block.timestamp
        );

        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(uint8(m.state), uint8(PredictionMarket.MarketState.Resolved));
        assertEq(uint8(m.winningOutcome), uint8(PredictionMarket.Outcome.Yes));
    }

    /// @notice TC-RS-002: Successful Resolution (NO Wins)
    function test_ResolveMarket_NoWins() public {
        warpToResolution(marketId);

        resolveMarket(marketId, PredictionMarket.Outcome.No);

        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(uint8(m.state), uint8(PredictionMarket.MarketState.Resolved));
        assertEq(uint8(m.winningOutcome), uint8(PredictionMarket.Outcome.No));
    }

    // ============ Failure Cases ============

    /// @notice TC-RS-003: Resolution Before Resolution Time
    function test_ResolveMarket_RevertIf_BeforeResolutionTime() public {
        vm.prank(admin);
        vm.expectRevert(PredictionMarket.MarketNotActive.selector);
        market.resolveMarket(marketId, PredictionMarket.Outcome.Yes);
    }

    /// @notice TC-RS-004: Resolution By Non-Admin
    function test_ResolveMarket_RevertIf_NonAdmin() public {
        warpToResolution(marketId);

        vm.prank(alice);
        vm.expectRevert(PredictionMarket.NotAdmin.selector);
        market.resolveMarket(marketId, PredictionMarket.Outcome.Yes);
    }

    /// @notice TC-RS-005: Resolution Of Already Resolved Market
    function test_ResolveMarket_RevertIf_AlreadyResolved() public {
        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        vm.prank(admin);
        vm.expectRevert(PredictionMarket.MarketAlreadyFinalized.selector);
        market.resolveMarket(marketId, PredictionMarket.Outcome.No);
    }

    /// @notice TC-RS-006: Resolution Of Cancelled Market
    function test_ResolveMarket_RevertIf_Cancelled() public {
        warpToResolution(marketId);
        cancelMarket(marketId);

        vm.prank(admin);
        vm.expectRevert(PredictionMarket.MarketAlreadyFinalized.selector);
        market.resolveMarket(marketId, PredictionMarket.Outcome.Yes);
    }

    /// @notice TC-RS-007: Resolution With No Opposition (Empty NO Pool)
    function test_ResolveMarket_RevertIf_NoOpposition_EmptyNoPool() public {
        // Create new market with only YES bets
        uint256 newMarketId = createMarket("Test?", block.timestamp + ONE_WEEK, 0);
        placeBet(alice, newMarketId, PredictionMarket.Outcome.Yes, usdc(100));
        warpToResolution(newMarketId);

        vm.prank(admin);
        vm.expectRevert(PredictionMarket.NoOpposition.selector);
        market.resolveMarket(newMarketId, PredictionMarket.Outcome.Yes);
    }

    /// @notice TC-RS-008: Resolution With No Opposition (Empty YES Pool)
    function test_ResolveMarket_RevertIf_NoOpposition_EmptyYesPool() public {
        // Create new market with only NO bets
        uint256 newMarketId = createMarket("Test?", block.timestamp + ONE_WEEK, 0);
        placeBet(bob, newMarketId, PredictionMarket.Outcome.No, usdc(100));
        warpToResolution(newMarketId);

        vm.prank(admin);
        vm.expectRevert(PredictionMarket.NoOpposition.selector);
        market.resolveMarket(newMarketId, PredictionMarket.Outcome.No);
    }

    /// @notice TC-RS-009: Resolution With Invalid Outcome
    function test_ResolveMarket_RevertIf_InvalidOutcome() public {
        warpToResolution(marketId);

        vm.prank(admin);
        vm.expectRevert(PredictionMarket.InvalidOutcome.selector);
        market.resolveMarket(marketId, PredictionMarket.Outcome.None);
    }

    /// @notice TC-RS-010: Resolution Of Non-Existent Market
    function test_ResolveMarket_RevertIf_InvalidMarket() public {
        vm.prank(admin);
        vm.expectRevert(PredictionMarket.InvalidMarket.selector);
        market.resolveMarket(999, PredictionMarket.Outcome.Yes);
    }
}
