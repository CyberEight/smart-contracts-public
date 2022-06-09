/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../utils/IEnums.sol";

contract CueContract is
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC721BurnableUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    struct Cue {
        uint256 spin;
        uint256 time;
        uint256 energy;
        uint256 accurate;
        uint256 strength;
        uint256 durability;
        bool transmog;
        IEnums.Rarity rarity;
    }

    address private constant DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    string public baseURI;

    CountersUpgradeable.Counter private _tokenIdCounter;
    mapping(address => bool) private _operators;
    mapping(uint256 => Cue) private _cues;

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
    event Mint(address recipient, uint256 tokenId);
    event Burn(uint256 tokenId);
    event UpgradeCue(
        uint256[] tokenIds,
        uint256[] spins,
        uint256[] times,
        uint256[] energies,
        uint256[] accurates,
        uint256[] strengths,
        uint256[] durabilities
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
        require(_operators[_msgSender()], "Cue: Sender is not operator");
        _;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
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

    function mint(
        address to,
        uint256 spin,
        uint256 time,
        uint256 energy,
        uint256 accurate,
        uint256 strength,
        uint256 durability,
        IEnums.Rarity rarity,
        bool transmog,
        string memory cid
    ) public whenNotPaused onlyOperator returns (uint256) {
        require(spin >= 1 && spin <= 30, "Spin is invalid");
        require(time >= 1 && time <= 30, "Time is invalid");
        require(energy >= 5 && energy <= 30, "Energy is invalid");
        require(accurate >= 1 && accurate <= 30, "Accurate is invalid");
        require(strength >= 1 && strength <= 30, "Strength is invalid");
        require(bytes(cid).length > 0, "CID must be not empty");

        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, cid);
        Cue storage cue = _cues[tokenId];
        cue.spin = spin;
        cue.time = time;
        cue.energy = energy;
        cue.accurate = accurate;
        cue.strength = strength;
        cue.durability = durability;
        cue.transmog = transmog;
        cue.rarity = rarity;
        _tokenIdCounter.increment();
        emit Mint(to, tokenId);
        return tokenId;
    }

    function mintBatch(
        address[] memory recipients,
        uint256[] memory spins,
        uint256[] memory times,
        uint256[] memory energies,
        uint256[] memory accurates,
        uint256[] memory strengths,
        uint256[] memory durabilities,
        IEnums.Rarity[] memory rarities,
        bool[] memory transmogs,
        string[] memory cids
    ) public whenNotPaused onlyOperator returns (uint256[] memory) {
        require(recipients.length > 0, "Recipient list must be not empty");
        require(
            spins.length == recipients.length,
            "Spins and recipients list must be same length"
        );
        require(
            times.length == recipients.length,
            "Times and recipients list must be same length"
        );
        require(
            energies.length == recipients.length,
            "Energies and recipients list must be same length"
        );
        require(
            accurates.length == recipients.length,
            "Accurates and recipients list must be same length"
        );
        require(
            strengths.length == recipients.length,
            "Strengths and recipients list must be same length"
        );
        require(
            durabilities.length == recipients.length,
            "Durabilities and recipients list must be same length"
        );
        require(
            rarities.length == recipients.length,
            "Rarities and recipients list must be same length"
        );
        require(
            transmogs.length == recipients.length,
            "Transmogs and recipients list must be same length"
        );
        require(
            cids.length == recipients.length,
            "CIDs and recipients list must be same length"
        );

        uint256[] memory tokenIds = new uint256[](spins.length);
        for (uint256 i = 0; i < recipients.length; i++) {
            tokenIds[i] = mint(
                recipients[i],
                spins[i],
                times[i],
                energies[i],
                accurates[i],
                strengths[i],
                durabilities[i],
                rarities[i],
                transmogs[i],
                cids[i]
            );
        }

        return tokenIds;
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

    function upgradeCue(
        uint256[] memory tokenIds,
        uint256[] memory spins,
        uint256[] memory times,
        uint256[] memory energies,
        uint256[] memory accurates,
        uint256[] memory strengths,
        uint256[] memory durabilities
    ) public whenNotPaused onlyOperator {
        require(tokenIds.length > 0, "Token Id list must be not empty");
        require(
            spins.length == tokenIds.length,
            "Spins and tokenIds list must be same length"
        );
        require(
            times.length == tokenIds.length,
            "Times and tokenIds list must be same length"
        );
        require(
            energies.length == tokenIds.length,
            "Energies and tokenIds list must be same length"
        );
        require(
            accurates.length == tokenIds.length,
            "Accurates and tokenIds list must be same length"
        );
        require(
            strengths.length == tokenIds.length,
            "Strengths and tokenIds list must be same length"
        );
        require(
            durabilities.length == tokenIds.length,
            "Durabilities and tokenIds list must be same length"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            Cue storage cue = _cues[tokenIds[i]];
            cue.spin = spins[i];
            cue.time = times[i];
            cue.energy = energies[i];
            cue.accurate = accurates[i];
            cue.strength = strengths[i];
            cue.durability = durabilities[i];
        }
        emit UpgradeCue(
            tokenIds,
            spins,
            times,
            energies,
            accurates,
            strengths,
            durabilities
        );
    }

    function cueInformation(uint256 tokenId)
        external
        view
        returns (
            uint256 spin,
            uint256 time,
            uint256 energy,
            uint256 accurate,
            uint256 strength,
            IEnums.Rarity rarity,
            uint256 durability,
            bool transmog
        )
    {
        Cue memory cue = _cues[tokenId];
        spin = cue.spin;
        time = cue.time;
        energy = cue.energy;
        accurate = cue.accurate;
        strength = cue.strength;
        rarity = cue.rarity;
        durability = cue.durability;
        transmog = cue.transmog;
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
        require(_tokenIds.length > 0, "Cue: Token Id list must not empty");
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
        require(_tokenIds.length > 0, "Cue: Token Id list must not empty");
        require(
            _tos.length == _tokenIds.length,
            "Cue: Recipient and tokenId list must be same length"
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
