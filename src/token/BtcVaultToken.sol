// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ManagedWithdrawRWA} from "./ManagedWithdrawRWA.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IBtcVaultStrategy} from "../interfaces/IBtcVaultStrategy.sol";

/**
 * @title BtcVaultToken
 * @notice Multi-collateral BTC vault token that extends ManagedWithdrawRWA
 * @dev Supports deposits of multiple BTC collateral types, redeems only in sovaBTC
 */
contract BtcVaultToken is ManagedWithdrawRWA {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error TokenNotSupported();
    error InsufficientAmount();
    error ZeroShares();
    error StandardDepositDisabled();

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralDeposited(
        address indexed depositor, address indexed token, uint256 amount, uint256 shares, address indexed receiver
    );

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimum deposit amount (0.001 BTC in 8 decimals)
    uint256 public constant MIN_DEPOSIT = 1e5;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param sovaBTC_ Address of sovaBTC (redemption asset, 8 decimals)
     * @param strategy_ Address of BtcVaultStrategy
     */
    constructor(string memory name_, string memory symbol_, address sovaBTC_, address strategy_)
        ManagedWithdrawRWA(name_, symbol_, sovaBTC_, 8, strategy_)
    {
        // ManagedWithdrawRWA handles all initialization
    }

    /*//////////////////////////////////////////////////////////////
                        MULTI-COLLATERAL DEPOSITS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposit BTC collateral tokens for shares
     * @param token Address of the BTC collateral token
     * @param amount Amount of collateral to deposit (8 decimals)
     * @param receiver Address to receive shares
     * @return shares Amount of shares minted (18 decimals)
     */
    function depositCollateral(address token, uint256 amount, address receiver)
        external
        nonReentrant
        returns (uint256 shares)
    {
        if (!IBtcVaultStrategy(strategy).isSupportedAsset(token)) revert TokenNotSupported();
        if (amount < MIN_DEPOSIT) revert InsufficientAmount();
        if (receiver == address(0)) revert InvalidAddress();

        // IMPORTANT: Since all collateral tokens are enforced to be 8 decimals (same as sovaBTC),
        // and treated as 1:1 with sovaBTC, we can pass amount directly to previewDeposit
        // which expects asset-denominated units (8 decimals). The ERC-4626 math handles
        // the conversion to 18-decimal shares internally.
        shares = previewDeposit(amount);

        if (shares == 0) revert ZeroShares();

        // Transfer collateral directly to strategy
        token.safeTransferFrom(msg.sender, strategy, amount);

        // Mint shares to receiver
        _mint(receiver, shares);

        emit CollateralDeposited(msg.sender, token, amount, shares, receiver);
    }

    /**
     * @notice Preview shares for collateral deposit
     * @param token Address of the BTC collateral token
     * @param amount Amount of collateral to deposit
     * @return shares Amount of shares that would be minted
     */
    function previewDepositCollateral(address token, uint256 amount) external view returns (uint256 shares) {
        if (!IBtcVaultStrategy(strategy).isSupportedAsset(token)) return 0;
        if (amount < MIN_DEPOSIT) return 0;

        // - Calculates shares = (amount * totalSupply) / totalAssets
        // - Where totalAssets comes from ReportedStrategy.balance() using current pricePerShare
        // - This ensures preview matches actual minting logic and respects vault NAV
        shares = previewDeposit(amount);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC-4626 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Standard ERC-4626 deposit is disabled
     * @dev Use depositCollateral for all deposits including sovaBTC
     */
    function deposit(uint256, address) public virtual override returns (uint256) {
        revert StandardDepositDisabled();
    }

    /**
     * @notice Standard ERC-4626 mint is disabled
     * @dev Use depositCollateral for all deposits including sovaBTC
     */
    function mint(uint256, address) public virtual override returns (uint256) {
        revert StandardDepositDisabled();
    }

    // Note: withdraw and redeem are already restricted in ManagedWithdrawRWA parent class
    // They require onlyStrategy modifier, so users cannot call them directly
}
