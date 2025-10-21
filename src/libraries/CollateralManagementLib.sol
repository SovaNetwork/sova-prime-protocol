// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

// Minimal interface for decimals check
interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

/**
 * @title CollateralManagementLib
 * @notice Library for managing multi-collateral operations in BtcVaultStrategy
 */
library CollateralManagementLib {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error AssetNotSupported();
    error AssetAlreadySupported();
    error InvalidDecimals();
    error InsufficientLiquidity();
    error InvalidAmount();
    error InvalidAddress();

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralAdded(address indexed token, uint8 decimals);
    event CollateralRemoved(address indexed token);
    event LiquidityAdded(uint256 amount);
    event LiquidityRemoved(uint256 amount);
    event CollateralWithdrawn(address indexed token, uint256 amount, address indexed to);
    event CollateralDeposited(address indexed depositor, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                        COLLATERAL MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add a new supported collateral token
     * @param token Address of the BTC collateral token
     * @param supportedAssets Mapping of supported assets
     * @param collateralTokens Array of collateral tokens
     * @param requiredDecimals Required decimals for collateral
     */
    function addCollateral(
        address token,
        mapping(address => bool) storage supportedAssets,
        address[] storage collateralTokens,
        uint8 requiredDecimals
    ) external {
        if (token == address(0)) revert InvalidAddress();
        if (supportedAssets[token]) revert AssetAlreadySupported();

        // Verify the token has required decimals
        try IERC20Decimals(token).decimals() returns (uint8 decimals) {
            if (decimals != requiredDecimals) revert InvalidDecimals();
        } catch {
            revert InvalidDecimals();
        }

        supportedAssets[token] = true;
        collateralTokens.push(token);

        emit CollateralAdded(token, requiredDecimals);
    }

    /**
     * @notice Remove a supported collateral token
     * @param token Address of the collateral token to remove
     * @param asset The main asset address (cannot be removed)
     * @param supportedAssets Mapping of supported assets
     * @param collateralTokens Array of collateral tokens
     */
    function removeCollateral(
        address token,
        address asset,
        mapping(address => bool) storage supportedAssets,
        address[] storage collateralTokens
    ) external {
        if (!supportedAssets[token]) revert AssetNotSupported();
        if (token == asset) revert InvalidAddress();

        supportedAssets[token] = false;

        // Remove from array
        for (uint256 i = 0; i < collateralTokens.length;) {
            if (collateralTokens[i] == token) {
                collateralTokens[i] = collateralTokens[collateralTokens.length - 1];
                collateralTokens.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }

        emit CollateralRemoved(token);
    }

    /**
     * @notice Deposit collateral directly to the strategy
     * @param token The collateral token to deposit
     * @param amount The amount to deposit
     * @param supportedAssets Mapping of supported assets
     */
    function depositCollateral(address token, uint256 amount, mapping(address => bool) storage supportedAssets)
        external
    {
        if (!supportedAssets[token]) revert AssetNotSupported();
        if (amount == 0) revert InvalidAmount();

        // Transfer collateral from sender to this contract
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralDeposited(msg.sender, token, amount);
    }

    /**
     * @notice Withdraw collateral to admin (emergency or rebalancing)
     * @param token Collateral token to withdraw
     * @param amount Amount to withdraw
     * @param to Recipient address
     * @param supportedAssets Mapping of supported assets
     */
    function withdrawCollateral(
        address token,
        uint256 amount,
        address to,
        mapping(address => bool) storage supportedAssets
    ) external {
        if (!supportedAssets[token]) revert AssetNotSupported();
        if (amount == 0) revert InvalidAmount();
        if (to == address(0)) revert InvalidAddress();

        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        if (amount > tokenBalance) revert InsufficientLiquidity();

        token.safeTransfer(to, amount);
        emit CollateralWithdrawn(token, amount, to);
    }

    /*//////////////////////////////////////////////////////////////
                        LIQUIDITY MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add sovaBTC for redemptions
     * @param asset The asset to add liquidity for
     * @param amount Amount to add
     */
    function addLiquidity(address asset, uint256 amount) external {
        if (amount == 0) revert InvalidAmount();

        // Transfer asset from manager
        asset.safeTransferFrom(msg.sender, address(this), amount);

        emit LiquidityAdded(amount);
    }

    /**
     * @notice Remove sovaBTC from strategy
     * @param asset The asset to remove liquidity for
     * @param amount Amount to remove
     * @param to Address to send the asset
     */
    function removeLiquidity(address asset, uint256 amount, address to) external {
        if (amount == 0) revert InvalidAmount();
        uint256 balance = IERC20(asset).balanceOf(address(this));
        if (amount > balance) revert InsufficientLiquidity();
        if (to == address(0)) revert InvalidAddress();

        asset.safeTransfer(to, amount);

        emit LiquidityRemoved(amount);
    }
}
