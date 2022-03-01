/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract CueContract is
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC721BurnableUpgradeable,
    ERC721EnumerableUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    enum Rarity {
        COMMON,
        MONO,
        RARE,
        EXOTIC,
        LEGEND
    }

    struct Cue {
        uint256 spin;
        uint256 time;
        uint256 energy;
        uint256 accurate;
        uint256 strength;
        uint256 durability;
        bool transmog;
        Rarity rarity;
    }

    address private constant DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

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

        OwnableUpgradeable.transferOwnership(ownerAddress_);
    }

    event Operator(address operator, bool isOperator);
    event Mint(address recipient, uint256 tokenId);
    event Burn(uint256 tokenId);

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
        uint256 durability
    ) public whenNotPaused onlyOperator returns (uint256) {
        require(spin >= 1 && spin <= 30, "Spin is invalid");
        require(time >= 1 && time <= 30, "Time is invalid");
        require(energy >= 5 && energy <= 30, "Energy is invalid");
        require(accurate >= 1 && accurate <= 30, "Accurate is invalid");
        require(strength >= 1 && strength <= 30, "Strength is invalid");
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(to, tokenId);
        Cue storage cue = _cues[tokenId];
        cue.spin = spin;
        cue.time = time;
        cue.energy = energy;
        cue.accurate = accurate;
        cue.strength = strength;
        cue.durability = durability;
        cue.transmog = true;
        cue.rarity = _rarity(
            cue.spin,
            cue.time,
            cue.energy,
            cue.accurate,
            cue.strength
        );
        _tokenIdCounter.increment();
        emit Mint(to, tokenId);
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

    function cueInformation(uint256 tokenId)
        external
        view
        returns (
            uint256 spin,
            uint256 time,
            uint256 energy,
            uint256 accurate,
            uint256 strength,
            Rarity rarity,
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

    function _burn(uint256 tokenId) internal override {
        safeTransferFrom(ownerOf(tokenId), DEAD_ADDRESS, tokenId);
        require(ownerOf(tokenId) == DEAD_ADDRESS, "Burn fail");
        emit Burn(tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://api.yourserver.com/token/cue/";
    }

    function _rarity(
        uint256 spin,
        uint256 time,
        uint256 energy,
        uint256 accurate,
        uint256 strength
    ) internal pure returns (Rarity) {
        uint256 sumAllStats = spin + time + energy + accurate + strength;
        uint256 statsAverage = sumAllStats / 5;
        if (statsAverage < 8) {
            return Rarity.COMMON;
        }
        if (statsAverage < 14) {
            return Rarity.MONO;
        }
        if (statsAverage < 20) {
            return Rarity.RARE;
        }
        if (statsAverage < 24) {
            return Rarity.EXOTIC;
        }
        if (statsAverage <= 30) {
            return Rarity.LEGEND;
        }
        revert("Stats is invalid");
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
