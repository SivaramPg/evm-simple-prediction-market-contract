// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../BaseTest.sol";

/// @title CancellationTest
/// @notice Unit tests for market cancellation functionality
contract CancellationTest is BaseTest {
    uint256 public marketId;

    function setUp() public override {
        super.setUp();
        marketId = createDefaultMarket();
        placeBet(alice, marketId, PredictionMarket.Outcome.Yes, usdc(100));
    }

    // ============ Success Cases ============

    /// @notice TC-CN-001: Successful Cancellation
    function test_CancelMarket_Success() public {
        warpToResolution(marketId);

        vm.expectEmit(true, true, true, true);
        emit MarketCancelled(marketId, usdc(100), 0, block.timestamp);

        cancelMarket(marketId);

        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(uint8(m.state), uint8(PredictionMarket.MarketState.Cancelled));
    }

    /// @notice Test cancellation with bets on both sides
    function test_CancelMarket_WithBothSides() public {
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(50));
        warpToResolution(marketId);

        cancelMarket(marketId);

        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(uint8(m.state), uint8(PredictionMarket.MarketState.Cancelled));
        assertEq(m.yesPool, usdc(100));
        assertEq(m.noPool, usdc(50));
    }

    // ============ Failure Cases ============

    /// @notice TC-CN-002: Cancellation Before Resolution Time
    function test_CancelMarket_RevertIf_BeforeResolutionTime() public {
        vm.prank(admin);
        vm.expectRevert(PredictionMarket.MarketNotActive.selector);
        market.cancelMarket(marketId);
    }

    /// @notice TC-CN-003: Cancellation By Non-Admin
    function test_CancelMarket_RevertIf_NonAdmin() public {
        warpToResolution(marketId);

        vm.prank(alice);
        vm.expectRevert(PredictionMarket.NotAdmin.selector);
        market.cancelMarket(marketId);
    }

    /// @notice TC-CN-004: Cancellation Of Already Resolved Market
    function test_CancelMarket_RevertIf_AlreadyResolved() public {
        placeBet(bob, marketId, PredictionMarket.Outcome.No, usdc(50));
        warpToResolution(marketId);
        resolveMarket(marketId, PredictionMarket.Outcome.Yes);

        vm.prank(admin);
        vm.expectRevert(PredictionMarket.MarketAlreadyFinalized.selector);
        market.cancelMarket(marketId);
    }

    /// @notice TC-CN-005: Cancellation Of Already Cancelled Market
    function test_CancelMarket_RevertIf_AlreadyCancelled() public {
        warpToResolution(marketId);
        cancelMarket(marketId);

        vm.prank(admin);
        vm.expectRevert(PredictionMarket.MarketAlreadyFinalized.selector);
        market.cancelMarket(marketId);
    }

    /// @notice TC-CN-006: Cancellation Of Non-Existent Market
    function test_CancelMarket_RevertIf_InvalidMarket() public {
        vm.prank(admin);
        vm.expectRevert(PredictionMarket.InvalidMarket.selector);
        market.cancelMarket(999);
    }
}
