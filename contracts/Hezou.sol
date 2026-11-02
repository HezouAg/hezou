pragma solidity 0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract Hezou is ERC721, EIP712, Ownable {
    uint256 public constant PRICE = 0.001 ether;
    uint256 public constant MAX_PER_WALLET = 5;
    uint256 public constant MAX_SUPPLY = 2222;
    bytes32 public constant MINT_TYPEHASH = keccak256("Mint(address to,uint256 tokenId,bytes32 dna,bytes32 score,bytes32 meta,uint256 deadline)");

    address payable public immutable treasury;
    address public signer;
    uint256 public totalSupply;
    string private baseTokenURI;
    string private collectionURI;

    mapping(address => uint256) public mintedBy;
    mapping(bytes32 => uint256) public tokenOfDna;
    mapping(uint256 => bytes32) public dnaOf;
    mapping(uint256 => bytes32) public scoreOf;
    mapping(uint256 => bytes32) public metaOf;

    event Minted(uint256 indexed tokenId, address indexed to, bytes32 indexed dna, bytes32 score);
    event SignerChanged(address signer);
    event BaseURIChanged(string baseURI);
    event ContractURIUpdated();
    event Withdrawn(uint256 amount);

    error WrongPrice();
    error Expired();
    error WalletLimit();
    error BadTokenId();
    error DnaTaken();
    error BadSignature();
    error ZeroAddress();
    error WithdrawFailed();

    constructor(address initialOwner, address initialSigner, address payable initialTreasury, string memory initialBaseURI, string memory initialContractURI)
        ERC721("HEZOU", "HEZOU")
        EIP712("HEZOU", "1")
        Ownable(initialOwner)
    {
        if (initialSigner == address(0) || initialTreasury == address(0)) revert ZeroAddress();
        treasury = initialTreasury;
        signer = initialSigner;
        baseTokenURI = initialBaseURI;
        collectionURI = initialContractURI;
    }

    function mint(uint256 tokenId, bytes32 dna, bytes32 score, bytes32 meta, uint256 deadline, bytes calldata signature) external payable {
        if (msg.value != PRICE) revert WrongPrice();
        if (block.timestamp > deadline) revert Expired();
        if (mintedBy[msg.sender] >= MAX_PER_WALLET) revert WalletLimit();
        if (tokenId == 0 || tokenId > MAX_SUPPLY) revert BadTokenId();
        if (tokenOfDna[dna] != 0) revert DnaTaken();

        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(MINT_TYPEHASH, msg.sender, tokenId, dna, score, meta, deadline)));
        if (ECDSA.recover(digest, signature) != signer) revert BadSignature();

        totalSupply += 1;
        mintedBy[msg.sender] += 1;
        tokenOfDna[dna] = tokenId;
        dnaOf[tokenId] = dna;
        scoreOf[tokenId] = score;
        metaOf[tokenId] = meta;
        _mint(msg.sender, tokenId);
        emit Minted(tokenId, msg.sender, dna, score);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        bytes32 meta = metaOf[tokenId];
        if (meta == bytes32(0)) return super.tokenURI(tokenId);
        return string.concat("ar://", Base64.encodeURL(abi.encodePacked(meta)));
    }

    function contractURI() external view returns (string memory) {
        return collectionURI;
    }

    function setContractURI(string calldata newContractURI) external onlyOwner {
        collectionURI = newContractURI;
        emit ContractURIUpdated();
    }

    function setSigner(address newSigner) external onlyOwner {
        if (newSigner == address(0)) revert ZeroAddress();
        signer = newSigner;
        emit SignerChanged(newSigner);
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseTokenURI = newBaseURI;
        emit BaseURIChanged(newBaseURI);
    }

    function withdraw() external {
        uint256 amount = address(this).balance;
        (bool ok,) = treasury.call{value: amount}("");
        if (!ok) revert WithdrawFailed();
        emit Withdrawn(amount);
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }
}
