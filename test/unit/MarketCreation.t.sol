// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../BaseTest.sol";

/// @title MarketCreationTest
/// @notice Unit tests for market creation functionality
contract MarketCreationTest is BaseTest {
    // ============ Success Cases ============

    /// @notice TC-MC-001: Successful Market Creation
    function test_CreateMarket_Success() public {
        string memory question = "Will Bitcoin reach $100k by 2025?";
        uint256 resolutionTime = block.timestamp + ONE_WEEK;

        vm.expectEmit(true, true, true, true);
        emit MarketCreated(1, question, resolutionTime, alice, 0);

        vm.prank(alice);
        uint256 marketId = market.createMarket(question, resolutionTime, 0);

        assertEq(marketId, 1);
        assertEq(market.marketCounter(), 1);

        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(m.id, 1);
        assertEq(m.question, question);
        assertEq(m.resolutionTime, resolutionTime);
        assertEq(uint8(m.state), uint8(PredictionMarket.MarketState.Active));
        assertEq(uint8(m.winningOutcome), uint8(PredictionMarket.Outcome.None));
        assertEq(m.yesPool, 0);
        assertEq(m.noPool, 0);
        assertEq(m.creationFee, 0);
        assertEq(m.creator, alice);
    }

    /// @notice TC-MC-002: Market Creation With Fee
    function test_CreateMarket_WithFee() public {
        string memory question = "Will Ethereum flip Bitcoin?";
        uint256 resolutionTime = block.timestamp + 30 days;
        uint256 fee = usdc(10);

        uint256 aliceBalanceBefore = stablecoin.balanceOf(alice);
        uint256 feeRecipientBalanceBefore = stablecoin.balanceOf(feeRecipient);

        vm.prank(alice);
        uint256 marketId = market.createMarket(question, resolutionTime, fee);

        assertEq(marketId, 1);
        assertEq(stablecoin.balanceOf(alice), aliceBalanceBefore - fee);
        assertEq(stablecoin.balanceOf(feeRecipient), feeRecipientBalanceBefore + fee);

        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(m.creationFee, fee);
    }

    /// @notice Test multiple market creation
    function test_CreateMarket_MultipleMarkets() public {
        vm.startPrank(alice);

        uint256 marketId1 = market.createMarket("Question 1?", block.timestamp + ONE_WEEK, 0);
        uint256 marketId2 = market.createMarket("Question 2?", block.timestamp + ONE_WEEK, 0);
        uint256 marketId3 = market.createMarket("Question 3?", block.timestamp + ONE_WEEK, 0);

        vm.stopPrank();

        assertEq(marketId1, 1);
        assertEq(marketId2, 2);
        assertEq(marketId3, 3);
        assertEq(market.marketCounter(), 3);
    }

    /// @notice Test config snapshot at creation
    function test_CreateMarket_ConfigSnapshot() public {
        vm.prank(alice);
        uint256 marketId = market.createMarket("Test?", block.timestamp + ONE_WEEK, 0);

        PredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(m.configSnapshot.feeRecipient, feeRecipient);
        assertEq(m.configSnapshot.maxFeePercentage, MAX_FEE_PERCENTAGE);

        // Update config
        vm.prank(admin);
        market.updateConfig(bob, 100);

        // Create new market
        vm.prank(alice);
        uint256 marketId2 = market.createMarket("Test 2?", block.timestamp + ONE_WEEK, 0);

        // Old market should have old config
        PredictionMarket.Market memory m1 = market.getMarket(marketId);
        assertEq(m1.configSnapshot.feeRecipient, feeRecipient);

        // New market should have new config
        PredictionMarket.Market memory m2 = market.getMarket(marketId2);
        assertEq(m2.configSnapshot.feeRecipient, bob);
        assertEq(m2.configSnapshot.maxFeePercentage, 100);
    }

    // ============ Failure Cases ============

    /// @notice TC-MC-003: Invalid Resolution Time (Past)
    function test_CreateMarket_RevertIf_ResolutionTimeInPast() public {
        // Warp to a future time first to avoid underflow
        vm.warp(block.timestamp + 2 hours);
        
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.InvalidResolutionTime.selector);
        market.createMarket("Test?", block.timestamp - 1 hours, 0);
    }

    /// @notice TC-MC-004: Invalid Resolution Time (Current)
    function test_CreateMarket_RevertIf_ResolutionTimeCurrent() public {
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.InvalidResolutionTime.selector);
        market.createMarket("Test?", block.timestamp, 0);
    }

    /// @notice TC-MC-006: Insufficient Balance For Fee
    function test_CreateMarket_RevertIf_InsufficientBalance() public {
        address poorUser = makeAddr("poorUser");

        vm.prank(poorUser);
        stablecoin.approve(address(market), type(uint256).max);

        vm.prank(poorUser);
        vm.expectRevert(PredictionMarket.InsufficientBalance.selector);
        market.createMarket("Test?", block.timestamp + ONE_WEEK, usdc(10));
    }

    /// @notice TC-MC-007: Insufficient Allowance For Fee
    function test_CreateMarket_RevertIf_InsufficientAllowance() public {
        address user = makeAddr("user");
        stablecoin.mint(user, usdc(100));

        // Don't approve

        vm.prank(user);
        vm.expectRevert(PredictionMarket.InsufficientAllowance.selector);
        market.createMarket("Test?", block.timestamp + ONE_WEEK, usdc(10));
    }

    /// @notice TC-MC-008: Empty Question
    function test_CreateMarket_RevertIf_EmptyQuestion() public {
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.EmptyQuestion.selector);
        market.createMarket("", block.timestamp + ONE_WEEK, 0);
    }

    /// @notice TC-MC-009: Market Creation When Paused
    function test_CreateMarket_RevertIf_Paused() public {
        vm.prank(admin);
        market.pause();

        vm.prank(alice);
        vm.expectRevert(PredictionMarket.Paused.selector);
        market.createMarket("Test?", block.timestamp + ONE_WEEK, 0);
    }
}
