// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGameToken {
    function balanceOf(address account) external view returns (uint256);
    function mint(address to, uint256 wholeAmount) external;
    function spendFrom(address from, uint256 wholeAmount) external;
}

interface IERC1155Receiver {
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns (bytes4);
    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external returns (bytes4);
}

/// @title ForestTrailSkins
/// @notice Hub ERC-1155 NFT Skin + klaim Token Koin (FTC) & Berlian (FTG) pada Ethereum Sepolia
contract ForestTrailSkins {
    uint8 public constant CURRENCY_COIN = 1;
    uint8 public constant CURRENCY_GEM = 2;
    uint256 public constant MAX_SKIN_ID = 16;

    string public constant name = "Forest Trail Tower Skins";
    string public constant symbol = "FTSKIN";
    string private _baseMetadataURI;

    address public owner;
    IGameToken public immutable coinToken;
    IGameToken public immutable gemToken;
    address public rewardSigner;

    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(address => bool) public starterClaimed;
    mapping(address => uint256) public nonces;
    mapping(address => uint256) public lastClaimAt;

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    event StarterClaimed(address indexed player, uint256 coins, uint256 gems);
    event WaveRewardClaimed(address indexed player, uint256 coins, uint256 gems, uint256 nonce);
    event SkinPurchased(address indexed player, uint256 indexed skinId, uint8 currencyType, uint256 price);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RewardSignerUpdated(address indexed signer);

    error OnlyOwner();
    error InvalidAddress();
    error InvalidLength();
    error NotApproved();
    error SelfApproval();
    error InsufficientBalance();
    error ERC1155Rejected();
    error StarterAlreadyClaimed();
    error EmptyReward();
    error InvalidSignature();
    error ExceedsClaimCap();
    error ClaimCooldown();
    error InvalidSkinId();
    error SkinAlreadyOwned();
    error InsufficientTokens();

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    constructor(
        address coinToken_,
        address gemToken_,
        string memory baseMetadataURI_,
        address rewardSigner_
    ) {
        if (coinToken_ == address(0) || gemToken_ == address(0)) revert InvalidAddress();
        owner = msg.sender;
        coinToken = IGameToken(coinToken_);
        gemToken = IGameToken(gemToken_);
        _baseMetadataURI = baseMetadataURI_;
        rewardSigner = rewardSigner_;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0xd9b67a26 || interfaceId == 0x0e89341c || interfaceId == 0x01ffc9a7;
    }

    function skinConfigs(uint256 skinId)
        public
        pure
        returns (uint8 currencyType, uint256 price, bool exists)
    {
        if (skinId == 1 || skinId == 5 || skinId == 9 || skinId == 13) return (CURRENCY_COIN, 60, true);
        if (skinId == 3 || skinId == 7 || skinId == 11 || skinId == 15) return (CURRENCY_COIN, 85, true);
        if (skinId == 2 || skinId == 6 || skinId == 10 || skinId == 14) return (CURRENCY_GEM, 20, true);
        if (skinId == 4) return (CURRENCY_GEM, 30, true);
        if (skinId == 8 || skinId == 12 || skinId == 16) return (CURRENCY_GEM, 35, true);
        return (0, 0, false);
    }

    function balanceOf(address account, uint256 id) public view returns (uint256) {
        if (account == address(0)) revert InvalidAddress();
        return _balances[id][account];
    }

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory batchBalances)
    {
        if (accounts.length != ids.length) revert InvalidLength();
        batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }
    }

    function setApprovalForAll(address operator, bool approved) external {
        if (msg.sender == operator) revert SelfApproval();
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external {
        if (from != msg.sender && !_operatorApprovals[from][msg.sender]) revert NotApproved();
        if (to == address(0)) revert InvalidAddress();
        if (_balances[id][from] < value) revert InsufficientBalance();
        _balances[id][from] -= value;
        _balances[id][to] += value;
        emit TransferSingle(msg.sender, from, to, id, value);
        if (to.code.length > 0) {
            if (
                IERC1155Receiver(to).onERC1155Received(msg.sender, from, id, value, data) !=
                IERC1155Receiver.onERC1155Received.selector
            ) revert ERC1155Rejected();
        }
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external {
        if (from != msg.sender && !_operatorApprovals[from][msg.sender]) revert NotApproved();
        if (to == address(0)) revert InvalidAddress();
        if (ids.length != values.length) revert InvalidLength();
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 val = values[i];
            if (_balances[id][from] < val) revert InsufficientBalance();
            _balances[id][from] -= val;
            _balances[id][to] += val;
        }
        emit TransferBatch(msg.sender, from, to, ids, values);
        if (to.code.length > 0) {
            if (
                IERC1155Receiver(to).onERC1155BatchReceived(msg.sender, from, ids, values, data) !=
                IERC1155Receiver.onERC1155BatchReceived.selector
            ) revert ERC1155Rejected();
        }
    }

    /// @notice Klaim modal awal 1x per wallet: 250 FTC (Koin) + 50 FTG (Berlian)
    function claimStarterPack() external {
        if (starterClaimed[msg.sender]) revert StarterAlreadyClaimed();
        starterClaimed[msg.sender] = true;
        coinToken.mint(msg.sender, 250);
        gemToken.mint(msg.sender, 50);
        emit StarterClaimed(msg.sender, 250, 50);
    }

    /// @notice Klaim token reward hasil wave dari dalam game ke wallet pemain
    function claimWaveReward(
        uint256 coinAmount,
        uint256 gemAmount,
        bytes calldata signature
    ) external {
        if (coinAmount == 0 && gemAmount == 0) revert EmptyReward();

        uint256 currentNonce = nonces[msg.sender];
        if (rewardSigner != address(0)) {
            if (signature.length != 65) revert InvalidSignature();
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := calldataload(signature.offset)
                s := calldataload(add(signature.offset, 32))
                v := byte(0, calldataload(add(signature.offset, 64)))
            }
            if (v < 27) v += 27;
            if (
                (v != 27 && v != 28) ||
                uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
            ) revert InvalidSignature();
            bytes32 payloadHash = keccak256(
                abi.encodePacked(block.chainid, address(this), msg.sender, coinAmount, gemAmount, currentNonce)
            );
            bytes32 ethSignedHash = keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", payloadHash)
            );
            address recovered = ecrecover(ethSignedHash, v, r, s);
            if (recovered == address(0) || recovered != rewardSigner) revert InvalidSignature();
        } else {
            if (coinAmount > 500 || gemAmount > 150) revert ExceedsClaimCap();
            if (block.timestamp < lastClaimAt[msg.sender] + 15) revert ClaimCooldown();
        }

        nonces[msg.sender] = currentNonce + 1;
        lastClaimAt[msg.sender] = block.timestamp;

        if (coinAmount > 0) {
            coinToken.mint(msg.sender, coinAmount);
        }
        if (gemAmount > 0) {
            gemToken.mint(msg.sender, gemAmount);
        }

        emit WaveRewardClaimed(msg.sender, coinAmount, gemAmount, currentNonce);
    }

    /// @notice Beli & mint Skin NFT (ERC-1155) memakai saldo FTC/FTG pemain
    function buySkin(uint256 skinId) external {
        (uint8 curr, uint256 price, bool exists) = skinConfigs(skinId);
        if (!exists) revert InvalidSkinId();
        if (_balances[skinId][msg.sender] != 0) revert SkinAlreadyOwned();

        if (curr == CURRENCY_COIN) {
            if (coinToken.balanceOf(msg.sender) < price * 1e18) revert InsufficientTokens();
            coinToken.spendFrom(msg.sender, price);
        } else {
            if (gemToken.balanceOf(msg.sender) < price * 1e18) revert InsufficientTokens();
            gemToken.spendFrom(msg.sender, price);
        }

        _balances[skinId][msg.sender] = 1;
        emit TransferSingle(msg.sender, address(0), msg.sender, skinId, 1);
        emit SkinPurchased(msg.sender, skinId, curr, price);
    }

    /// @notice Ambil seluruh status on-chain pemain dalam 1 kali RPC call
    function getPlayerProfile(address player)
        external
        view
        returns (
            uint256 coinBalance,
            uint256 gemBalance,
            bool hasClaimedStarter,
            uint256[16] memory skinOwned,
            uint256 playerNonce
        )
    {
        coinBalance = coinToken.balanceOf(player) / 1e18;
        gemBalance = gemToken.balanceOf(player) / 1e18;
        hasClaimedStarter = starterClaimed[player];
        playerNonce = nonces[player];
        for (uint256 i = 0; i < MAX_SKIN_ID; i++) {
            skinOwned[i] = _balances[i + 1][player];
        }
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseMetadataURI = newBaseURI;
    }

    function setRewardSigner(address newSigner) external onlyOwner {
        rewardSigner = newSigner;
        emit RewardSignerUpdated(newSigner);
    }

    function uri(uint256 tokenId) public view returns (string memory) {
        if (tokenId == 0) {
            return string(abi.encodePacked(_baseMetadataURI, "0.json"));
        }
        uint256 temp = tokenId;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (tokenId != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + (tokenId % 10)));
            tokenId /= 10;
        }
        return string(abi.encodePacked(_baseMetadataURI, string(buffer), ".json"));
    }
}
