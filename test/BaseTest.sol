// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/// @title BaseTest
/// @notice Base test contract with common setup and utilities
abstract contract BaseTest is Test {
    // ============ Events (copied from PredictionMarket for testing) ============
    event MarketCreated(
        uint256 indexed marketId,
        string question,
        uint256 resolutionTime,
        address indexed creator,
        uint256 fee
    );
    event MarketResolved(
        uint256 indexed marketId,
        PredictionMarket.Outcome winningOutcome,
        uint256 yesPool,
        uint256 noPool,
        uint256 timestamp
    );
    event MarketCancelled(
        uint256 indexed marketId,
        uint256 yesPool,
        uint256 noPool,
        uint256 timestamp
    );
    event BetPlaced(
        uint256 indexed marketId,
        address indexed bettor,
        PredictionMarket.Outcome outcome,
        uint256 amount,
        uint256 timestamp
    );
    event WinningsClaimed(
        uint256 indexed marketId,
        address indexed bettor,
        uint256 amount,
        uint256 timestamp
    );
    event ConfigUpdated(
        address indexed admin,
        address feeRecipient,
        uint256 maxFeePercentage
    );
    event ContractPaused(address indexed admin);
    event ContractUnpaused(address indexed admin);
    // ============ Contracts ============
    PredictionMarket public market;
    MockERC20 public stablecoin;

    // ============ Users ============
    address public admin;
    address public feeRecipient;
    address public alice;
    address public bob;
    address public charlie;

    // ============ Constants ============
    uint8 public constant DECIMALS = 6;
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** DECIMALS;
    uint256 public constant MAX_FEE_PERCENTAGE = 500; // 5%
    uint256 public constant ONE_DAY = 1 days;
    uint256 public constant ONE_WEEK = 7 days;

    // ============ Setup ============

    function setUp() public virtual {
        // Create users
        admin = makeAddr("admin");
        feeRecipient = makeAddr("feeRecipient");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Deploy stablecoin
        vm.startPrank(admin);
        stablecoin = new MockERC20("Mock USDC", "mUSDC", DECIMALS, 0);

        // Deploy prediction market
        market = new PredictionMarket(
            address(stablecoin),
            DECIMALS,
            admin,
            feeRecipient,
            MAX_FEE_PERCENTAGE
        );
        vm.stopPrank();

        // Mint tokens to users
        stablecoin.mint(alice, INITIAL_SUPPLY);
        stablecoin.mint(bob, INITIAL_SUPPLY);
        stablecoin.mint(charlie, INITIAL_SUPPLY);

        // Approve market contract
        vm.prank(alice);
        stablecoin.approve(address(market), type(uint256).max);

        vm.prank(bob);
        stablecoin.approve(address(market), type(uint256).max);

        vm.prank(charlie);
        stablecoin.approve(address(market), type(uint256).max);
    }

    // ============ Helper Functions ============

    /// @notice Creates a market with default parameters
    function createDefaultMarket() internal returns (uint256 marketId) {
        return createMarket("Will Bitcoin reach $100k?", block.timestamp + ONE_WEEK, 0);
    }

    /// @notice Creates a market with custom parameters
    function createMarket(
        string memory question,
        uint256 resolutionTime,
        uint256 fee
    ) internal returns (uint256 marketId) {
        vm.prank(alice);
        return market.createMarket(question, resolutionTime, fee);
    }

    /// @notice Places a bet on a market
    function placeBet(
        address bettor,
        uint256 marketId,
        PredictionMarket.Outcome outcome,
        uint256 amount
    ) internal {
        vm.prank(bettor);
        market.placeBet(marketId, outcome, amount);
    }

    /// @notice Resolves a market
    function resolveMarket(uint256 marketId, PredictionMarket.Outcome outcome) internal {
        vm.prank(admin);
        market.resolveMarket(marketId, outcome);
    }

    /// @notice Cancels a market
    function cancelMarket(uint256 marketId) internal {
        vm.prank(admin);
        market.cancelMarket(marketId);
    }

    /// @notice Claims winnings
    function claimWinnings(address user, uint256 marketId) internal {
        vm.prank(user);
        market.claimWinnings(marketId);
    }

    /// @notice Warps time to after resolution time
    function warpToResolution(uint256 marketId) internal {
        PredictionMarket.Market memory m = market.getMarket(marketId);
        vm.warp(m.resolutionTime + 1);
    }

    /// @notice Helper to get 100 USDC with proper decimals
    function usdc(uint256 amount) internal pure returns (uint256) {
        return amount * 10 ** DECIMALS;
    }
}
