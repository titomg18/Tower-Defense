// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ForestTrailGem (FTG)
/// @notice ERC-20 Token Berlian untuk game Tower Defense: Forest Trail
contract ForestTrailGem {
    string public constant name = "Forest Trail Gem";
    string public constant symbol = "FTG";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    address public owner;
    address public gameHub;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event GameHubUpdated(address indexed newHub);

    error OnlyOwner();
    error OnlyGameHub();
    error InvalidAddress();
    error InsufficientFTG();
    error InsufficientAllowance();

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyGameHub() {
        if (msg.sender != gameHub) revert OnlyGameHub();
        _;
    }

    constructor(address _gameHub) {
        if (_gameHub == address(0)) revert InvalidAddress();
        owner = msg.sender;
        gameHub = _gameHub;
    }

    function setGameHub(address _gameHub) external onlyOwner {
        if (_gameHub == address(0)) revert InvalidAddress();
        gameHub = _gameHub;
        emit GameHubUpdated(_gameHub);
    }

    function mint(address to, uint256 wholeAmount) external onlyGameHub {
        if (to == address(0)) revert InvalidAddress();
        uint256 amount = wholeAmount * 1e18;
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function spendFrom(address from, uint256 wholeAmount) external onlyGameHub {
        uint256 amount = wholeAmount * 1e18;
        if (balanceOf[from] < amount) revert InsufficientFTG();
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        if (to == address(0)) revert InvalidAddress();
        if (balanceOf[msg.sender] < value) revert InsufficientFTG();
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        if (to == address(0)) revert InvalidAddress();
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < value) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - value;
        }
        if (balanceOf[from] < value) revert InsufficientFTG();
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
}
