/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BoxContract is
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC721BurnableUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    struct Box {
        uint256 typeBox;
        bytes32 boxData;
    }

    address private constant DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    string public baseURI;

    CountersUpgradeable.Counter private _tokenIdCounter;
    mapping(address => bool) private _operators;
    mapping(uint256 => Box) private _boxOfTokenId;
    mapping(uint256 => bool) private _isINOBox;

    function initialize(
        string memory name_,
        string memory symbol_,
        address ownerAddress_
    ) external initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        __Pausable_init();
        __ERC721_init(name_, symbol_);
        __ERC721Burnable_init();
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        OwnableUpgradeable.transferOwnership(ownerAddress_);
    }

    event Operator(address operator, bool isOperator);
    event Mint(
        address recipient,
        uint256 tokenId,
        uint256 typeBox,
        bytes32 hashData,
        string cid
    );
    event Burn(uint256 tokenId);
    event MintBatch(
        address[] recipients,
        uint256[] tokenIds,
        uint256[] typeBoxes,
        bytes32[] hashDatas,
        string[] cids
    );
    event TransferBatchToSingleAddress(
        address from,
        address to,
        uint256[] tokenIds
    );
    event TransferBatchToMultipleAddress(
        address from,
        address[] tos,
        uint256[] tokenIds
    );

    modifier onlyOperator() {
        require(_operators[_msgSender()], "Box: Sender is not operator");
        _;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function mint(
        address to,
        uint256 typeBox,
        bytes32 boxData,
        bool isINOBox,
        string memory cid
    ) public onlyOperator whenNotPaused returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, cid);

        Box storage box = _boxOfTokenId[tokenId];
        box.typeBox = typeBox;
        box.boxData = boxData;

        _isINOBox[tokenId] = isINOBox;
        emit Mint(to, tokenId, typeBox, boxData, cid);
        return tokenId;
    }

    function burn(uint256 tokenId)
        public
        virtual
        override
        whenNotPaused
        onlyOperator
    {
        _burn(tokenId);
    }

    function mintBatch(
        address[] memory recipients,
        uint256[] memory typeBoxes,
        bytes32[] memory boxDatas,
        bool[] memory isINOBoxs,
        string[] memory cids
    ) public whenNotPaused onlyOperator returns (uint256[] memory) {
        require(recipients.length > 0, "Recipient list must be not empty");
        require(
            typeBoxes.length == recipients.length,
            "Type boxes and recipients list must be same length"
        );
        require(
            boxDatas.length == recipients.length,
            "Box datas and recipients list must be same length"
        );
        uint256[] memory tokenIds = new uint256[](typeBoxes.length);
        for (uint256 i = 0; i < recipients.length; i++) {
            tokenIds[i] = mint(
                recipients[i],
                typeBoxes[i],
                boxDatas[i],
                isINOBoxs[i],
                cids[i]
            );
        }

        emit MintBatch(recipients, tokenIds, typeBoxes, boxDatas, cids);
        return tokenIds;
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory tokenIds
    ) public whenNotPaused {
        _safeBatchTransferFrom(from, to, tokenIds, "");
    }

    function safeBatchTransferFromWithData(
        address from,
        address to,
        uint256[] memory tokenIds,
        bytes memory data
    ) public whenNotPaused {
        _safeBatchTransferFrom(from, to, tokenIds, data);
    }

    function batchTransferToMultipleAddress(
        address from,
        address[] memory tos,
        uint256[] memory tokenIds
    ) public whenNotPaused {
        _batchTransferToMultipleAddress(from, tos, tokenIds, "");
    }

    function batchTransferToMultipleAddressWithData(
        address from,
        address[] memory tos,
        uint256[] memory tokenIds,
        bytes memory data
    ) public whenNotPaused {
        _batchTransferToMultipleAddress(from, tos, tokenIds, data);
    }

    function setBaseURI(string memory uri) external onlyOwner {
        baseURI = uri;
    }

    function boxInformation(uint256 tokenId)
        public
        view
        returns (
            uint256 typeBox,
            bytes32 boxData,
            bool isINOBox
        )
    {
        Box memory box = _boxOfTokenId[tokenId];
        boxData = box.boxData;
        isINOBox = _isINOBox[tokenId];
        typeBox = box.typeBox;
        // 1000 is prefix of box INO
        if (isINOBox) {
            typeBox = 1000 + box.typeBox;
        }
    }

    function setOperator(address operator, bool isOperator_)
        external
        onlyOwner
    {
        _operators[operator] = isOperator_;
        emit Operator(operator, isOperator_);
    }

    function isOperator(address operator) external view returns (bool) {
        return _operators[operator];
    }

    /**
     *  @dev get all token held by a user address
     *  @param owner is the token holder
     */
    function getTokensOfOwner(address owner)
        external
        view
        returns (uint256[] memory)
    {
        // get the number of token being hold by owner
        uint256 tokenCount = balanceOf(owner);

        if (tokenCount == 0) {
            // if owner has no balance return an empty array
            return new uint256[](0);
        } else {
            // query owner's tokens by index and add them to the token array
            uint256[] memory tokenList = new uint256[](tokenCount);
            for (uint256 i = 0; i < tokenCount; i++)
                tokenList[i] = tokenOfOwnerByIndex(owner, i);
            return tokenList;
        }
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        safeTransferFrom(ownerOf(tokenId), DEAD_ADDRESS, tokenId);
        require(ownerOf(tokenId) == DEAD_ADDRESS, "Burn fail");
        emit Burn(tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function _safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _tokenIds,
        bytes memory _data
    ) internal {
        require(_tokenIds.length > 0, "Box: Token Id list must not empty");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            safeTransferFrom(_from, _to, _tokenIds[i], _data);
        }
        emit TransferBatchToSingleAddress(_from, _to, _tokenIds);
    }

    function _batchTransferToMultipleAddress(
        address _from,
        address[] memory _tos,
        uint256[] memory _tokenIds,
        bytes memory _data
    ) internal {
        require(_tokenIds.length > 0, "Box: Token Id list must not empty");
        require(
            _tos.length == _tokenIds.length,
            "Box: Recipient and tokenId list must be same length"
        );
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            safeTransferFrom(_from, _tos[i], _tokenIds[i], _data);
        }
        emit TransferBatchToMultipleAddress(_from, _tos, _tokenIds);
    }

    function _isApprovedOrOwner(address _address, uint256 _tokenId)
        internal
        view
        override
        returns (bool)
    {
        bool result = super._isApprovedOrOwner(_address, _tokenId);
        if (_operators[_address]) {
            return true;
        }
        return result;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
