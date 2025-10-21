// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ERC20} from "solady/tokens/ERC20.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

/**
 * @title SovaBTC
 * @notice Tokenized Bitcoin on the EVM. Each unit represents one satoshi.
 */
contract SovaBTC is ERC20, OwnableRoles {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string public constant NAME = "Sova Bitcoin V1";
    string public constant SYMBOL = "sovabtc";
    uint8 public constant DECIMALS = 8;
    uint256 public constant MAX_MINT_AMOUNT = 1000 * 10 ** 8; // 1000 BTC in satoshis

    /*//////////////////////////////////////////////////////////////
                               ROLE CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MINT_ROLE = _ROLE_0;
    uint256 public constant BURN_ROLE = _ROLE_1;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error BlacklistedAddress(address user);
    error NotBlacklisted(address user);
    error ZeroAddress();
    error MintAmountExceedsMaximum(uint256 amount, uint256 maximum);

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    event AddedToBlackList(address indexed user);
    event RemovedFromBlackList(address indexed user);
    event DestroyedBlackFunds(address indexed user, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                               STATE
    //////////////////////////////////////////////////////////////*/

    mapping(address => bool) public isBlacklisted;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor
     * @param owner_ Initial owner address (admin)
     * @param mintManager_ Initial mint manager address
     * @param burnManager_ Initial burn manager address
     */
    constructor(address owner_, address mintManager_, address burnManager_) {
        if (owner_ == address(0)) revert ZeroAddress();
        if (mintManager_ == address(0)) revert ZeroAddress();
        if (burnManager_ == address(0)) revert ZeroAddress();

        _initializeOwner(owner_);
        _grantRoles(mintManager_, MINT_ROLE);
        _grantRoles(burnManager_, BURN_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC20 METADATA
    //////////////////////////////////////////////////////////////*/

    function name() public pure override returns (string memory) {
        return NAME;
    }

    function symbol() public pure override returns (string memory) {
        return SYMBOL;
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    /*//////////////////////////////////////////////////////////////
                        MINT/BURN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mint new tokens
     * @dev Maximum mint amount is 1000 BTC per transaction to prevent fat finger errors
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyRoles(MINT_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        if (isBlacklisted[to]) revert BlacklistedAddress(to);
        if (amount > MAX_MINT_AMOUNT) revert MintAmountExceedsMaximum(amount, MAX_MINT_AMOUNT);
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens from the burn manager's balance
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) external onlyRoles(BURN_ROLE) {
        _burn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        BLACKLIST MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add an address to the blacklist
     * @param user Address to blacklist
     */
    function addBlackList(address user) external onlyOwner {
        if (user == address(0)) revert ZeroAddress();
        if (isBlacklisted[user]) revert BlacklistedAddress(user);
        isBlacklisted[user] = true;
        emit AddedToBlackList(user);
    }

    /**
     * @notice Remove an address from the blacklist
     * @param user Address to remove from blacklist
     */
    function removeBlackList(address user) external onlyOwner {
        if (!isBlacklisted[user]) revert NotBlacklisted(user);
        isBlacklisted[user] = false;
        emit RemovedFromBlackList(user);
    }

    /**
     * @notice Destroy all tokens held by a blacklisted address
     * @dev This permanently removes tokens from circulation
     * @param user Blacklisted address whose tokens will be destroyed
     */
    function destroyBlackFunds(address user) external onlyOwner {
        if (!isBlacklisted[user]) revert NotBlacklisted(user);
        uint256 balance = balanceOf(user);
        if (balance > 0) {
            _burn(user, balance);
            emit DestroyedBlackFunds(user, balance);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        TRANSFER OVERRIDE
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Hook that is called before any token transfer
     * @notice Prevents blacklisted addresses from transferring tokens
     * @dev Allows burning from blacklisted addresses (to == address(0))
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        // Allow burning from blacklisted addresses
        if (to == address(0)) {
            return;
        }

        if (from != address(0) && isBlacklisted[from]) {
            revert BlacklistedAddress(from);
        }
        if (isBlacklisted[to]) {
            revert BlacklistedAddress(to);
        }
    }
}
