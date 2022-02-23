// https://etherscan.io/address/0x86C35FA9665002C08801805280fF6a077B23c98A#code

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract CatBloxGenesis is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private tokenCounter;

    string public baseURI;
    string public provenanceHash;

    uint256 public constant MAX_CATS_PER_WALLET = 2;
    uint256 public immutable maxCats;

    bool public isMilkListActive;
    bool public isReserveListActive;
    bool public isPublicSaleActive;

    uint256 public milkListSalePrice = 0.18 ether;
    uint256 public reserveListSalePrice = 0.22 ether;
    uint256 public publicSalePrice = 0.22 ether;

    bytes32 public milkListMerkleRoot;
    bytes32 public reserveListMerkleRoot;

    mapping(address => uint256) public milkListMintCounts;
    mapping(address => uint256) public reserveListMintCounts;
    mapping(address => uint256) public publicListMintCounts;

    // ============ ACCESS CONTROL/SANITY MODIFIERS ============

    modifier milkListActive() {
        require(isMilkListActive, "Milk list not active");
        _;
    }
    
    modifier reserveListActive() {
        require(isReserveListActive, "Reserve list not active");
        _;
    }

    modifier publicSaleActive() {
        require(isPublicSaleActive, "Public sale not active");
        _;
    }

    modifier totalNotExceeded(uint256 numberOfTokens) {
        require(
            tokenCounter.current() + numberOfTokens <= maxCats,
            "Not enough cats remaining to mint"
        );
        _;
    }

    modifier isCorrectPayment(uint256 price, uint256 numberOfTokens) {
        require(
            price * numberOfTokens == msg.value,
            "Incorrect ETH value sent"
        );
        _;
    }

    modifier isValidMerkleProof(bytes32[] calldata merkleProof, bytes32 root) {
        require(
            MerkleProof.verify(
                merkleProof,
                root,
                keccak256(abi.encodePacked(msg.sender))
            ),
            "Address does not exist in list"
        );
        _;
    }

    constructor(string memory _baseURI, uint256 _maxCats) ERC721("CatBloxGenesis", "CATBLOXGEN") {
        baseURI = _baseURI;
        maxCats = _maxCats;
    }

    // ============ OWNER ONLY FUNCTION FOR MINTING ============

    function mintToTeam(uint256 numberOfTokens, address recipient)
        external
        onlyOwner
        totalNotExceeded(numberOfTokens)
    {
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(recipient, nextTokenId());
        }
    }

    // ============ PUBLIC FUNCTIONS FOR MINTING ============

    function mintMilkListSale(
        uint8 numberOfTokens,
        bytes32[] calldata merkleProof
    )
        external
        payable
        nonReentrant
        milkListActive
        isCorrectPayment(milkListSalePrice, numberOfTokens)
        totalNotExceeded(numberOfTokens)
        isValidMerkleProof(merkleProof, milkListMerkleRoot)
    {
        uint256 numAlreadyMinted = milkListMintCounts[msg.sender];
        require(numAlreadyMinted + numberOfTokens <= MAX_CATS_PER_WALLET, "ML: Two cats max per wallet");
        milkListMintCounts[msg.sender] = numAlreadyMinted + numberOfTokens;

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, nextTokenId());
        }
    }

    function mintReserveListSale(
        uint8 numberOfTokens,
        bytes32[] calldata merkleProof
    )
        external
        payable
        nonReentrant
        reserveListActive
        isCorrectPayment(reserveListSalePrice, numberOfTokens)
        totalNotExceeded(numberOfTokens)
        isValidMerkleProof(merkleProof, reserveListMerkleRoot)
    {
        uint256 numAlreadyMinted = reserveListMintCounts[msg.sender];
        require(numAlreadyMinted + numberOfTokens <= MAX_CATS_PER_WALLET, "RL: Two cats max per wallet");
        reserveListMintCounts[msg.sender] = numAlreadyMinted + numberOfTokens;

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, nextTokenId());
        }
    }

    function publicMint(uint256 numberOfTokens)
        external
        payable
        nonReentrant
        publicSaleActive
        isCorrectPayment(publicSalePrice, numberOfTokens)
        totalNotExceeded(numberOfTokens)
    {
        uint256 numAlreadyMinted = publicListMintCounts[msg.sender];
        require(numAlreadyMinted + numberOfTokens <= MAX_CATS_PER_WALLET, "PM: Two cats max per wallet");
        publicListMintCounts[msg.sender] = numAlreadyMinted + numberOfTokens;

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, nextTokenId());
        }
    }

    // ============ PUBLIC READ-ONLY FUNCTIONS ============

    function totalSupply() external view returns (uint256) {
        return tokenCounter.current();
    }

    // ============ OWNER-ONLY ADMIN FUNCTIONS ============

    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function setProvenanceHash(string memory _hash) external onlyOwner {
        provenanceHash = _hash;
    }

    // Set prices 

    function setPublicSalePrice(uint256 _price) external onlyOwner {
        publicSalePrice = _price;
    }

    function setMilkListPrice(uint256 _price) external onlyOwner {
        milkListSalePrice = _price;
    }

    function setReserveListPrice(uint256 _price) external onlyOwner {
        reserveListSalePrice = _price;
    }

    // Toggle Sales Active / Inactive 

    function setPublicSaleActive(bool _isPublicSaleActive) external onlyOwner {
        isPublicSaleActive = _isPublicSaleActive;
    }

    function setMilkListActive(bool _isMilkListActive) external onlyOwner {
        isMilkListActive = _isMilkListActive;
    }

    function setReserveListActive(bool _isReserveListActive) external onlyOwner {
        isReserveListActive = _isReserveListActive;
    }

    // Set Merkle Roots 

    function setMilkListMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        milkListMerkleRoot = _merkleRoot;
    }

    function setReserveListMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        reserveListMerkleRoot = _merkleRoot;
    }

    // Withdrawal 

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function withdrawTokens(IERC20 token) public onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        token.transfer(msg.sender, balance);
    }

    // ============ SUPPORTING FUNCTIONS ============

    function nextTokenId() private returns (uint256) {
        tokenCounter.increment();
        return tokenCounter.current();
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Nonexistent token");

        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }
}