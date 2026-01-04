// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/// @title DeployMockTokenScript
/// @notice Deploys a mock ERC20 token for testing
contract DeployMockTokenScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Token configuration
        string memory name = vm.envOr("TOKEN_NAME", string("Mock USDC"));
        string memory symbol = vm.envOr("TOKEN_SYMBOL", string("mUSDC"));
        uint8 decimals = uint8(vm.envOr("TOKEN_DECIMALS", uint256(6)));
        uint256 initialSupply = vm.envOr("INITIAL_SUPPLY", uint256(1_000_000)) * 10 ** decimals;

        console.log("=== Mock Token Configuration ===");
        console.log("Deployer:", deployer);
        console.log("Name:", name);
        console.log("Symbol:", symbol);
        console.log("Decimals:", decimals);
        console.log("Initial Supply:", initialSupply);

        vm.startBroadcast(deployerPrivateKey);

        MockERC20 token = new MockERC20(name, symbol, decimals, initialSupply);

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("Token Address:", address(token));
        console.log("Deployer Balance:", token.balanceOf(deployer));
    }
}
