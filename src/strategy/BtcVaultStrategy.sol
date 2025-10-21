// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ManagedWithdrawReportedStrategy} from "./ManagedWithdrawRWAStrategy.sol";
import {BtcVaultToken} from "../token/BtcVaultToken.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {CollateralManagementLib} from "../libraries/CollateralManagementLib.sol";
import {CollateralViewLib} from "../libraries/CollateralViewLib.sol";

/// @title BtcVaultStrategy
/// @notice Multi-collateral BTC vault strategy with managed withdrawals
contract BtcVaultStrategy is ManagedWithdrawReportedStrategy {
    using SafeTransferLib for address;

    uint8 public constant COLLATERAL_DECIMALS = 8;
    mapping(address => bool) public supportedAssets;
    address[] public collateralTokens;

    /// @notice Initialize the strategy
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address roleManager_,
        address manager_,
        address sovaBTC_,
        uint8 assetDecimals_,
        bytes memory initData
    ) public virtual override {
        super.initialize(name_, symbol_, roleManager_, manager_, sovaBTC_, assetDecimals_, initData);
        require(assetDecimals_ == 8);
        supportedAssets[sovaBTC_] = true;
        collateralTokens.push(sovaBTC_);
    }

    /// @notice Deploy a new BtcVaultToken for this strategy
    function _deployToken(string calldata name_, string calldata symbol_, address asset_, uint8 /* assetDecimals_ */)
        internal
        virtual
        override
        returns (address)
    {
        return address(new BtcVaultToken(name_, symbol_, asset_, address(this)));
    }

    /// @notice Add a new supported collateral token
    function addCollateral(address token) external onlyManager {
        CollateralManagementLib.addCollateral(token, supportedAssets, collateralTokens, COLLATERAL_DECIMALS);
    }

    /// @notice Remove a supported collateral token
    function removeCollateral(address token) external onlyManager {
        CollateralManagementLib.removeCollateral(token, asset, supportedAssets, collateralTokens);
    }

    /// @notice Deposit collateral directly to the strategy
    function depositCollateral(address token, uint256 amount) external {
        CollateralManagementLib.depositCollateral(token, amount, supportedAssets);
    }

    /// @notice Withdraw collateral to admin
    function withdrawCollateral(address token, uint256 amount, address to) external onlyManager {
        CollateralManagementLib.withdrawCollateral(token, amount, to, supportedAssets);
    }

    /// @notice Add sovaBTC for redemptions
    function addLiquidity(uint256 amount) external onlyManager {
        CollateralManagementLib.addLiquidity(asset, amount);
    }

    /// @notice Remove sovaBTC from strategy
    function removeLiquidity(uint256 amount, address to) external onlyManager {
        CollateralManagementLib.removeLiquidity(asset, amount, to);
    }

    /// @notice Approve token to withdraw assets during redemptions
    function approveTokenWithdrawal(uint256 amount) external onlyManager {
        asset.safeApprove(sToken, 0);
        asset.safeApprove(sToken, amount);
    }

    /// @notice Check if an asset is supported
    function isSupportedAsset(address token) external view returns (bool) {
        return supportedAssets[token];
    }

    /// @notice Get list of all supported collateral tokens
    function getSupportedCollaterals() external view returns (address[] memory) {
        return collateralTokens;
    }

    /// @notice Get total collateral assets value
    function totalCollateralAssets() external view returns (uint256) {
        return CollateralViewLib.totalCollateralAssets(collateralTokens);
    }

    /// @notice Get balance of a specific collateral token
    function collateralBalance(address token) external view returns (uint256) {
        return CollateralViewLib.collateralBalance(token, supportedAssets);
    }

    /// @notice Get available sovaBTC balance for redemptions
    function availableLiquidity() external view returns (uint256) {
        return CollateralViewLib.availableLiquidity(asset);
    }

    /*//////////////////////////////////////////////////////////////
                            EIP-712 OVERRIDE
    //////////////////////////////////////////////////////////////*/

    /// @notice EIP-712 Type Hash Constants
    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /**
     * @notice Calculate the EIP-712 domain separator with correct contract name
     * @return The domain separator
     */
    function _domainSeparator() internal view virtual override returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("BtcVaultStrategy")),
                keccak256(bytes("V1")),
                block.chainid,
                address(this)
            )
        );
    }
}
