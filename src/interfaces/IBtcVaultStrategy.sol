// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/**
 * @title IBtcVaultStrategy
 * @notice Interface for the BTC vault strategy managing multi-collateral assets
 */
interface IBtcVaultStrategy {
    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralAdded(address indexed token, uint8 decimals);
    event CollateralRemoved(address indexed token);
    event LiquidityAdded(uint256 amount);
    event LiquidityRemoved(uint256 amount);
    event CollateralWithdrawn(address indexed token, uint256 amount, address indexed to);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error AssetNotSupported();
    error AssetAlreadySupported();
    error InvalidDecimals();
    error InsufficientLiquidity();
    error InvalidAmount();
    error InvalidAddress();
    error UnauthorizedCaller();

    /*//////////////////////////////////////////////////////////////
                        COLLATERAL MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add a new supported collateral token
     * @dev All collateral must have 8 decimals
     * @param token Address of the BTC collateral token
     */
    function addCollateral(address token) external;

    /**
     * @notice Remove a supported collateral token
     * @param token Address of the collateral token to remove
     */
    function removeCollateral(address token) external;

    /**
     * @notice Check if an asset is supported
     * @param token Address of the token to check
     * @return Whether the token is supported
     */
    function isSupportedAsset(address token) external view returns (bool);

    /**
     * @notice Get list of all supported collateral tokens
     * @return Array of supported token addresses
     */
    function getSupportedCollaterals() external view returns (address[] memory);

    /*//////////////////////////////////////////////////////////////
                        LIQUIDITY MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add sovaBTC liquidity for redemptions
     * @param amount Amount of sovaBTC to add
     */
    function addLiquidity(uint256 amount) external;

    /**
     * @notice Remove excess sovaBTC liquidity
     * @param amount Amount of sovaBTC to remove
     * @param to Address to send the sovaBTC
     */
    function removeLiquidity(uint256 amount, address to) external;

    /*//////////////////////////////////////////////////////////////
                        VAULT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Withdraw collateral to admin
     * @param token Collateral token to withdraw
     * @param amount Amount to withdraw
     * @param to Recipient address
     */
    function withdrawCollateral(address token, uint256 amount, address to) external;

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get total collateral assets value in sovaBTC terms (1:1 for all BTC variants)
     * @dev This sums raw collateral balances without NAV adjustment
     * @return Total value of all collateral in 8 decimal units
     */
    function totalCollateralAssets() external view returns (uint256);

    /**
     * @notice Get balance of a specific collateral token
     * @param token Address of the collateral token
     * @return Balance of the token held by strategy
     */
    function collateralBalance(address token) external view returns (uint256);

    /**
     * @notice Get available sovaBTC balance for redemptions
     * @return Current sovaBTC balance in the strategy
     */
    function availableLiquidity() external view returns (uint256);
}
