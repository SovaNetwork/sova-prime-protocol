// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from "solady/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/**
 * @title MockERC20WithLimit
 * @notice A simple ERC20 token for testing purposes. Capped mint function to mint a fixed amount.
 */
contract MockERC20WithLimit is ERC20, Ownable {
    // Token metadata
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    // Minting controls
    mapping(address => bool) public hasMinted;
    uint256 public constant MAX_SUPPLY = 21_000_000;

    /**
     * @notice Contract constructor
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param decimals_ Token decimals
     */
    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        require(decimals_ >= 2, "Decimals must be at least 2");
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _initializeOwner(msg.sender);
    }

    /**
     * @notice Returns the name of the token
     * @return Token name
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of the token
     * @return Token symbol
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Returns the decimals of the token
     * @return Token decimals
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Mint tokens to msg.sender
     */
    function mint() external {
        require(!hasMinted[msg.sender], "Address has already minted");
        require(totalSupply() + (5 * 10**_decimals) / 100 <= MAX_SUPPLY * 10**_decimals, "Max supply exceeded");

        hasMinted[msg.sender] = true;
        _mint(msg.sender, (5 * 10**_decimals) / 100);
    }

    /**
     * @notice Burn tokens from a specified address
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
