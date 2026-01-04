// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

/// @title CreateMarketScript
/// @notice Creates a new prediction market
contract CreateMarketScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Market contract address
        address marketAddress = vm.envAddress("MARKET_ADDRESS");
        
        // Market parameters
        string memory question = vm.envOr("QUESTION", string("Will Bitcoin reach $100k by 2025?"));
        uint256 resolutionDays = vm.envOr("RESOLUTION_DAYS", uint256(7));
        uint256 resolutionTime = block.timestamp + (resolutionDays * 1 days);
        uint256 feeAmount = vm.envOr("FEE_AMOUNT", uint256(0));

        console.log("=== Create Market ===");
        console.log("Market Contract:", marketAddress);
        console.log("Question:", question);
        console.log("Resolution Time:", resolutionTime);
        console.log("Fee Amount:", feeAmount);

        PredictionMarket market = PredictionMarket(marketAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Approve fee if needed
        if (feeAmount > 0) {
            IERC20 stablecoin = market.stablecoin();
            stablecoin.approve(marketAddress, feeAmount);
            console.log("Approved fee:", feeAmount);
        }

        // Create market
        uint256 marketId = market.createMarket(question, resolutionTime, feeAmount);

        vm.stopBroadcast();

        console.log("\n=== Market Created ===");
        console.log("Market ID:", marketId);

        // Show market details
        PredictionMarket.Market memory m = market.getMarket(marketId);
        console.log("Creator:", m.creator);
        console.log("State: Active");
    }
}
