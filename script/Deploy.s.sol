// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/// @title DeployScript
/// @notice Deploys the PredictionMarket contract and optionally a mock stablecoin
contract DeployScript is Script {
    // Default values (can be overridden via environment variables)
    uint8 constant DEFAULT_DECIMALS = 6;
    uint256 constant DEFAULT_MAX_FEE = 500; // 5%
    uint256 constant MOCK_INITIAL_SUPPLY = 1_000_000 * 10 ** DEFAULT_DECIMALS;

    function run() external {
        // Load configuration from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Check for existing stablecoin or deploy mock
        address stablecoinAddress = vm.envOr("STABLECOIN_ADDRESS", address(0));
        uint8 stablecoinDecimals = uint8(vm.envOr("STABLECOIN_DECIMALS", uint256(DEFAULT_DECIMALS)));
        
        // Admin and fee recipient (default to deployer)
        address admin = vm.envOr("ADMIN_ADDRESS", deployer);
        address feeRecipient = vm.envOr("FEE_RECIPIENT", deployer);
        uint256 maxFeePercentage = vm.envOr("MAX_FEE_PERCENTAGE", DEFAULT_MAX_FEE);

        console.log("=== Deployment Configuration ===");
        console.log("Deployer:", deployer);
        console.log("Admin:", admin);
        console.log("Fee Recipient:", feeRecipient);
        console.log("Max Fee Percentage:", maxFeePercentage, "basis points");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock stablecoin if not provided
        MockERC20 stablecoin;
        if (stablecoinAddress == address(0)) {
            console.log("\nDeploying Mock USDC...");
            stablecoin = new MockERC20("Mock USDC", "mUSDC", stablecoinDecimals, MOCK_INITIAL_SUPPLY);
            stablecoinAddress = address(stablecoin);
            console.log("Mock USDC deployed at:", stablecoinAddress);
        } else {
            console.log("\nUsing existing stablecoin:", stablecoinAddress);
        }

        // Deploy PredictionMarket
        console.log("\nDeploying PredictionMarket...");
        PredictionMarket market = new PredictionMarket(
            stablecoinAddress,
            stablecoinDecimals,
            admin,
            feeRecipient,
            maxFeePercentage
        );

        vm.stopBroadcast();

        // Log deployment info
        console.log("\n=== Deployment Complete ===");
        console.log("PredictionMarket:", address(market));
        console.log("Stablecoin:", stablecoinAddress);
        console.log("Stablecoin Decimals:", stablecoinDecimals);

        // Verify configuration
        console.log("\n=== Verification ===");
        PredictionMarket.Config memory config = market.getConfig();
        console.log("Config Admin:", config.admin);
        console.log("Config Fee Recipient:", config.feeRecipient);
        console.log("Config Max Fee:", config.maxFeePercentage);
        console.log("Config Paused:", config.paused);
    }
}
