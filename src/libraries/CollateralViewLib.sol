// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

/**
 * @title CollateralViewLib
 * @notice Library for view functions in BtcVaultStrategy
 */
library CollateralViewLib {
    /**
     * @notice Get total collateral assets value in sovaBTC terms (1:1 for all BTC variants)
     * @dev This sums raw collateral balances without NAV adjustment
     * @param collateralTokens Array of collateral token addresses
     * @return Total value of all collateral in 8 decimal units
     */
    function totalCollateralAssets(address[] storage collateralTokens) external view returns (uint256) {
        uint256 total = 0;

        // Sum all collateral balances (all have 1:1 value with sovaBTC)
        for (uint256 i = 0; i < collateralTokens.length;) {
            address token = collateralTokens[i];
            uint256 tokenBalance = IERC20(token).balanceOf(address(this));
            total += tokenBalance; // All BTC tokens are 8 decimals, 1:1 with sovaBTC

            unchecked {
                ++i;
            }
        }

        return total;
    }

    /**
     * @notice Get balance of a specific collateral token
     * @param token Address of the collateral token
     * @param supportedAssets Mapping of supported assets
     * @return Balance of the token held by strategy
     */
    function collateralBalance(address token, mapping(address => bool) storage supportedAssets)
        external
        view
        returns (uint256)
    {
        if (!supportedAssets[token]) return 0;
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Get available sovaBTC balance for redemptions
     * @param asset The asset address
     * @return Current sovaBTC balance in the strategy
     */
    function availableLiquidity(address asset) external view returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }
}
