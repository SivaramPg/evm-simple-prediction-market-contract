// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

/// @title InteractScript
/// @notice Interacts with the PredictionMarket contract (bet, resolve, cancel, claim)
contract InteractScript is Script {
    function run() external {
        string memory action = vm.envString("ACTION");

        if (keccak256(bytes(action)) == keccak256("bet")) {
            placeBet();
        } else if (keccak256(bytes(action)) == keccak256("resolve")) {
            resolveMarket();
        } else if (keccak256(bytes(action)) == keccak256("cancel")) {
            cancelMarket();
        } else if (keccak256(bytes(action)) == keccak256("claim")) {
            claimWinnings();
        } else if (keccak256(bytes(action)) == keccak256("info")) {
            showMarketInfo();
        } else {
            revert("Unknown action. Use: bet, resolve, cancel, claim, info");
        }
    }

    function placeBet() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address marketAddress = vm.envAddress("MARKET_ADDRESS");
        uint256 marketId = vm.envUint("MARKET_ID");
        bool isYes = vm.envBool("IS_YES");
        uint256 amount = vm.envUint("AMOUNT");

        console.log("=== Place Bet ===");
        console.log("Market ID:", marketId);
        console.log("Outcome:", isYes ? "YES" : "NO");
        console.log("Amount:", amount);

        PredictionMarket market = PredictionMarket(marketAddress);
        IERC20 stablecoin = market.stablecoin();

        vm.startBroadcast(deployerPrivateKey);

        // Approve
        stablecoin.approve(marketAddress, amount);

        // Place bet
        PredictionMarket.Outcome outcome = isYes
            ? PredictionMarket.Outcome.Yes
            : PredictionMarket.Outcome.No;
        market.placeBet(marketId, outcome, amount);

        vm.stopBroadcast();

        console.log("\n=== Bet Placed ===");
        PredictionMarket.Market memory m = market.getMarket(marketId);
        console.log("YES Pool:", m.yesPool);
        console.log("NO Pool:", m.noPool);
    }

    function resolveMarket() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address marketAddress = vm.envAddress("MARKET_ADDRESS");
        uint256 marketId = vm.envUint("MARKET_ID");
        bool yesWins = vm.envBool("YES_WINS");

        console.log("=== Resolve Market ===");
        console.log("Market ID:", marketId);
        console.log("Winner:", yesWins ? "YES" : "NO");

        PredictionMarket market = PredictionMarket(marketAddress);

        vm.startBroadcast(deployerPrivateKey);

        PredictionMarket.Outcome winningOutcome = yesWins
            ? PredictionMarket.Outcome.Yes
            : PredictionMarket.Outcome.No;
        market.resolveMarket(marketId, winningOutcome);

        vm.stopBroadcast();

        console.log("\n=== Market Resolved ===");
    }

    function cancelMarket() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address marketAddress = vm.envAddress("MARKET_ADDRESS");
        uint256 marketId = vm.envUint("MARKET_ID");

        console.log("=== Cancel Market ===");
        console.log("Market ID:", marketId);

        PredictionMarket market = PredictionMarket(marketAddress);

        vm.startBroadcast(deployerPrivateKey);

        market.cancelMarket(marketId);

        vm.stopBroadcast();

        console.log("\n=== Market Cancelled ===");
    }

    function claimWinnings() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address marketAddress = vm.envAddress("MARKET_ADDRESS");
        uint256 marketId = vm.envUint("MARKET_ID");

        console.log("=== Claim Winnings ===");
        console.log("Market ID:", marketId);

        PredictionMarket market = PredictionMarket(marketAddress);
        address user = vm.addr(deployerPrivateKey);

        // Calculate expected payout
        uint256 expectedPayout = market.calculatePayout(marketId, user);
        console.log("Expected Payout:", expectedPayout);

        vm.startBroadcast(deployerPrivateKey);

        market.claimWinnings(marketId);

        vm.stopBroadcast();

        console.log("\n=== Winnings Claimed ===");
    }

    function showMarketInfo() internal view {
        address marketAddress = vm.envAddress("MARKET_ADDRESS");
        uint256 marketId = vm.envUint("MARKET_ID");

        PredictionMarket market = PredictionMarket(marketAddress);
        PredictionMarket.Market memory m = market.getMarket(marketId);

        console.log("=== Market Info ===");
        console.log("ID:", m.id);
        console.log("Question:", m.question);
        console.log("Resolution Time:", m.resolutionTime);
        console.log("State:", uint8(m.state));
        console.log("Winning Outcome:", uint8(m.winningOutcome));
        console.log("YES Pool:", m.yesPool);
        console.log("NO Pool:", m.noPool);
        console.log("Creator:", m.creator);
        console.log("Created At:", m.createdAt);
    }
}
