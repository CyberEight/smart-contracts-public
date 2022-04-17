// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BreakToken is
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC20BurnableUpgradeable
{
    using AddressUpgradeable for address;

    mapping(address => bool) private _operators;

    function initialize(
        string memory name_,
        string memory symbol_,
        address ownerAddress_
    ) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        __Pausable_init();
        __ERC20_init(name_, symbol_);
        __ERC20Burnable_init();

        OwnableUpgradeable.transferOwnership(ownerAddress_);
    }

    event Operator(address operator, bool isOperator);
    event Mint(address recipient, uint256 amount);

    modifier onlyOperator() {
        require(_operators[msg.sender], "BreakToken: Sender is not operator");
        _;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function mint(address account, uint256 amount)
        public
        whenNotPaused
        onlyOperator
    {
        _mint(account, amount);
        emit Mint(account, amount);
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

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override whenNotPaused returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        return super.approve(spender, amount);
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        return super.increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        return super.decreaseAllowance(spender, subtractedValue);
    }

    function burn(uint256 amount) public virtual override whenNotPaused {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        virtual
        override
        whenNotPaused
    {
        super.burnFrom(account, amount);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
