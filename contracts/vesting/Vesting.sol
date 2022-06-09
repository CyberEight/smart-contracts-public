// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../utils/ArrayLib.sol";
import "hardhat/console.sol";

contract Vesting is Ownable, Pausable, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    struct Scheme {
        string name;
        uint256 startTsTGE;
        uint256 cliffPeriodTGE;
        uint256 unlockPercentTGE;
        uint256 cliffPeriod;
        uint256 startTsUnlockVesting;
        uint256 duration;
        uint256 period;
        bool isActive;
    }

    struct Subscription {
        address wallet;
        uint256 schemeId;
        Scheme scheme;
        uint256 endTs;
        uint256 totalVestingAmount;
        uint256 periodVestingAmount;
        uint256 vestedAmount;
        bool isActive;
    }

    struct SubscriptionInput {
        address wallet;
        uint256 schemeId;
        uint256 startTsTGE;
        uint256 totalVestingAmount;
        uint256 vestedAmount;
        uint256 depositAmount;
    }

    uint32 public constant ZOOM = 10000;
    IERC20 public erc20Token;
    address public emergencyWallet;
    //@dev epoch time and in seconds
    uint256 public tge;

    Counters.Counter public schemeCount;
    Counters.Counter public subscriptionCount;

    mapping(address => bool) _admins;
    // @dev get Subscription by index
    mapping(uint256 => Subscription) _subscriptions;
    // @dev list SubscriptionIds which wallets participate
    mapping(address => uint256[]) _participatedSubscriptionIds;
    // @dev get Scheme by index
    mapping(uint256 => Scheme) _schemes;

    constructor(
        address token,
        address emergencyAddress,
        address ownerAddress
    ) {
        erc20Token = IERC20(token);
        emergencyWallet = emergencyAddress;

        Ownable.transferOwnership(ownerAddress);
    }

    event SchemeCreated(
        uint256 schemeId,
        string name,
        uint256 startTsTGE,
        uint256 cliffPeriodTGE,
        uint256 unlockPercentTGE,
        uint256 cliffPeriod,
        uint256 startTsUnlockVesting,
        uint256 duration,
        uint256 period,
        bool isActive
    );
    event SchemeUpdated(
        uint256 schemeId,
        string name,
        uint256 startTsTGE,
        uint256 cliffPeriodTGE,
        uint256 unlockPercentTGE,
        uint256 cliffPeriod,
        uint256 startTsUnlockVesting,
        uint256 duration,
        uint256 period,
        bool isActive
    );
    event SchemeActivated(uint256 schemeId, bool isActive);
    event SubscriptionAdded(
        uint256 subscriptionId,
        Subscription subscription,
        uint256 depositAmount
    );
    event SubscriptionDisabled(uint256 subscriptionId);
    event ClaimSucceeded(
        address wallet,
        uint256 totalClaimableAmount,
        uint256[] subscriptionIds,
        uint256[] claimableAmounts
    );
    event VestingContractConfigured(address erc20Contract);
    event EmergencyWalletConfigured(address emergencyWallet);
    event EmergencyWithdrawalExecuted(address emergencyWallet, uint256 amount);
    event AdminAdded(address admin, bool isAdmin);
    event TokenGenerationEventConfigured(uint256 time);

    modifier onlyAdmin() {
        _onlyAdmin();
        require(_admins[_msgSender()], "Vesting: Sender is not admin");
        _;
    }

    modifier schemeExist(uint256 schemeId) {
        _schemeExist(schemeId);
        _;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * contract setup functions
     */
    function setERC20Token(address erc20Contract) external onlyOwner {
        require(
            erc20Contract.isContract() && erc20Contract != address(0),
            "ERC20 address must be a smart contract"
        );
        erc20Token = IERC20(erc20Contract);
        emit VestingContractConfigured(erc20Contract);
    }

    function setEmergencyWallet(address newEmergencyWallet) external onlyOwner {
        require(
            newEmergencyWallet != address(0),
            "New emergency address is invalid"
        );
        emergencyWallet = newEmergencyWallet;
        emit EmergencyWalletConfigured(emergencyWallet);
    }

    function setAdmin(address admin, bool isAdmin_) public onlyOwner {
        _admins[admin] = isAdmin_;
        emit AdminAdded(admin, isAdmin_);
    }

    function setTGE(uint256 time) external onlyOwner {
        require(tge == 0, "Can only be initialized once");
        require(time > 0, "Time must be greater than zero");
        tge = time;
        emit TokenGenerationEventConfigured(tge);
    }

    function emergencyWithdraw() public whenPaused onlyOwner {
        uint256 balanceOfThis = erc20Token.balanceOf(address(this));
        if (balanceOfThis > 0) {
            erc20Token.transfer(emergencyWallet, balanceOfThis);
        }
        emit EmergencyWithdrawalExecuted(emergencyWallet, balanceOfThis);
    }

    function addScheme(
        string memory name,
        uint256 startTsTGE,
        uint256 cliffPeriodTGE,
        uint256 unlockPercentTGE,
        uint256 cliffPeriod,
        uint256 duration,
        uint256 period
    ) external onlyAdmin {
        uint256 startTsUnlockVesting;
        (startTsTGE, startTsUnlockVesting) = _validateSchemeInfo(
            name,
            startTsTGE,
            cliffPeriodTGE,
            unlockPercentTGE,
            cliffPeriod,
            duration,
            period
        );

        schemeCount.increment();
        uint256 schemeId = schemeCount.current();

        Scheme storage newScheme = _schemes[schemeId];
        newScheme.name = name;
        newScheme.startTsTGE = startTsTGE;
        newScheme.cliffPeriodTGE = cliffPeriodTGE;
        newScheme.unlockPercentTGE = unlockPercentTGE;
        newScheme.cliffPeriod = cliffPeriod;
        newScheme.startTsUnlockVesting = startTsUnlockVesting;
        newScheme.duration = duration;
        newScheme.period = period;
        newScheme.isActive = true;

        emit SchemeCreated(
            schemeId,
            newScheme.name,
            newScheme.startTsTGE,
            newScheme.cliffPeriodTGE,
            newScheme.unlockPercentTGE,
            newScheme.cliffPeriod,
            newScheme.startTsUnlockVesting,
            newScheme.duration,
            newScheme.period,
            newScheme.isActive
        );
    }

    function updateScheme(
        uint256 schemeId,
        string memory name,
        uint256 startTsTGE,
        uint256 cliffPeriodTGE,
        uint256 unlockPercentTGE,
        uint256 cliffPeriod,
        uint256 duration,
        uint256 period
    ) external onlyAdmin schemeExist(schemeId) {
        uint256 startTsUnlockVesting;
        (startTsTGE, startTsUnlockVesting) = _validateSchemeInfo(
            name,
            startTsTGE,
            cliffPeriodTGE,
            unlockPercentTGE,
            cliffPeriod,
            duration,
            period
        );

        Scheme storage scheme = _schemes[schemeId];
        scheme.name = name;
        scheme.startTsTGE = startTsTGE;
        scheme.cliffPeriodTGE = cliffPeriodTGE;
        scheme.unlockPercentTGE = unlockPercentTGE;
        scheme.cliffPeriod = cliffPeriod;
        scheme.startTsUnlockVesting = startTsUnlockVesting;
        scheme.duration = duration;
        scheme.period = period;

        emit SchemeUpdated(
            schemeId,
            scheme.name,
            scheme.startTsTGE,
            scheme.cliffPeriodTGE,
            scheme.unlockPercentTGE,
            scheme.cliffPeriod,
            scheme.startTsUnlockVesting,
            scheme.duration,
            scheme.period,
            scheme.isActive
        );
    }

    function toggleSchemeActivation(uint256 schemeId, bool isActive)
        external
        onlyAdmin
        schemeExist(schemeId)
    {
        _schemes[schemeId].isActive = isActive;
        emit SchemeActivated(schemeId, isActive);
    }

    function addSubscription(SubscriptionInput memory subscriptionInput)
        public
        onlyAdmin
        schemeExist(subscriptionInput.schemeId)
    {
        require(
            subscriptionInput.wallet != address(0),
            "Wallet must be not zero address"
        );
        require(
            subscriptionInput.totalVestingAmount > 0,
            "Total vesting amount must be greater than zero"
        );
        require(
            subscriptionInput.vestedAmount <
                subscriptionInput.totalVestingAmount,
            "Vested amount must be less than total vesting amount"
        );

        Scheme memory scheme = _schemes[subscriptionInput.schemeId];

        require(scheme.isActive, "Scheme is not active");
        if (subscriptionInput.startTsTGE > 0) {
            require(
                subscriptionInput.startTsTGE >= scheme.startTsTGE,
                "Start time must be greater than start time of scheme"
            );
        }

        subscriptionCount.increment();
        uint256 subscriptionId = subscriptionCount.current();

        _participatedSubscriptionIds[subscriptionInput.wallet].push(
            subscriptionId
        );

        Subscription storage subscription = _subscriptions[subscriptionId];
        subscription.schemeId = subscriptionInput.schemeId;
        subscription.wallet = subscriptionInput.wallet;
        // scheme of subscription
        subscription.scheme.name = scheme.name;
        subscription.scheme.startTsTGE = subscriptionInput.startTsTGE == 0
            ? scheme.startTsTGE
            : subscriptionInput.startTsTGE;
        subscription.scheme.cliffPeriodTGE = scheme.cliffPeriodTGE;
        subscription.scheme.unlockPercentTGE = scheme.unlockPercentTGE;
        subscription.scheme.cliffPeriod = scheme.cliffPeriod;
        subscription.scheme.startTsUnlockVesting =
            subscription.scheme.startTsTGE +
            scheme.cliffPeriod;
        subscription.scheme.duration = scheme.duration;
        subscription.scheme.period = scheme.period;
        subscription.scheme.isActive = scheme.isActive;

        subscription.endTs =
            subscription.scheme.startTsUnlockVesting +
            scheme.duration;
        subscription.totalVestingAmount = subscriptionInput.totalVestingAmount;
        uint256 vestingCount_ = scheme.duration / scheme.period;
        subscription.periodVestingAmount =
            subscriptionInput.totalVestingAmount /
            vestingCount_;
        subscription.vestedAmount = subscriptionInput.vestedAmount;
        subscription.isActive = true;

        {
            // Deposit token for vesting plan
            if (subscriptionInput.depositAmount > 0) {
                require(
                    subscriptionInput.depositAmount ==
                        subscriptionInput.totalVestingAmount -
                            subscriptionInput.vestedAmount,
                    "Deposit amount must be equal to remaining vesting amount"
                );
                erc20Token.safeTransferFrom(
                    _msgSender(),
                    address(this),
                    subscriptionInput.depositAmount
                );
            }
        }

        emit SubscriptionAdded(
            subscriptionId,
            subscription,
            subscriptionInput.depositAmount
        );
    }

    function addSubscriptions(SubscriptionInput[] memory subscriptionInputs)
        external
        onlyAdmin
    {
        for (uint256 i = 0; i < subscriptionInputs.length; i++) {
            addSubscription(subscriptionInputs[i]);
        }
    }

    function disableVesting(uint256 subscriptionId) external onlyAdmin {
        require(
            subscriptionId >= 1 &&
                subscriptionId <= subscriptionCount.current(),
            "Subscription ID is invalid"
        );
        Subscription storage subscription = _subscriptions[subscriptionId];
        subscription.isActive = false;

        emit SubscriptionDisabled(subscriptionId);
    }

    function claimAll() external whenNotPaused nonReentrant {
        uint256 totalClaimableSubscriptions = _getTotalClaimableSubscriptions(
            _participatedSubscriptionIds[_msgSender()]
        );
        _claim(
            _participatedSubscriptionIds[_msgSender()],
            totalClaimableSubscriptions
        );
    }

    function claim(uint256[] memory subscriptionId)
        external
        whenNotPaused
        nonReentrant
    {
        require(
            subscriptionId.length > 0,
            "Requiring at least one subscription ID"
        );

        uint256 totalClaimableSubscriptions = _getTotalClaimableSubscriptions(
            subscriptionId
        );
        _claim(subscriptionId, totalClaimableSubscriptions);
    }

    function schemeInfo(uint256 schemeId)
        external
        view
        returns (Scheme memory)
    {
        return _schemes[schemeId];
    }

    function subscriptionInfo(uint256 subscriptionId)
        external
        view
        returns (Subscription memory subscription, uint256 claimableAmount)
    {
        subscription = _subscriptions[subscriptionId];
        claimableAmount = _getAvailableAmount(subscriptionId);
    }

    function getParticipatedSubscriptionIds(address wallet)
        external
        view
        returns (uint256[] memory)
    {
        return _participatedSubscriptionIds[wallet];
    }

    function getClaimableAmount(address wallet)
        external
        view
        returns (uint256 totalVestingAmount, uint256 availableAmount)
    {
        uint256[] memory subscriptionIds = _participatedSubscriptionIds[wallet];

        for (uint256 i = 0; i < subscriptionIds.length; i++) {
            if (_subscriptions[subscriptionIds[i]].isActive) {
                totalVestingAmount += _subscriptions[subscriptionIds[i]]
                    .totalVestingAmount;
                availableAmount += _getAvailableAmount(subscriptionIds[i]);
            }
        }
    }

    function isAdmin(address wallet) public view returns (bool) {
        return _admins[wallet];
    }

    function _onlyAdmin() private view {
        require(_admins[_msgSender()], "Vesting: Sender is not admin");
    }

    function _schemeExist(uint256 schemeId) private view {
        require(
            schemeId >= 1 && schemeId <= schemeCount.current(),
            "Scheme is not exist"
        );
    }

    function _validateSchemeInfo(
        string memory name,
        uint256 startTs,
        uint256 cliffPeriodTGE,
        uint256 unlockPercentTGE,
        uint256 cliffPeriod,
        uint256 duration,
        uint256 period
    ) private view returns (uint256 startTsTGE, uint256 startTsUnlockVesting) {
        require(bytes(name).length > 0, "Name must not be empty");
        require(tge != 0, "Have not set tge");
        if (cliffPeriodTGE > 0) {
            require(
                unlockPercentTGE > 0,
                "Unlock percent at TGE must be greater than zero"
            );
        }

        startTsTGE = startTs == 0 ? tge : startTs;
        require(startTsTGE >= tge, "Start time must be greater than TGE");

        startTsUnlockVesting = startTsTGE + cliffPeriod;
        require(duration > 0, "Duration must be greater than zero");
        require(
            period > 0 && period <= duration,
            "Period must be greater than zero and less than duration"
        );
        require(duration % period == 0, "Duration must be divisible by period");
    }

    function _claim(
        uint256[] memory _subscriptionIds,
        uint256 _totalClaimableSubscriptions
    ) internal {
        uint256 index = 0;
        uint256 totalClaimableAmount = 0;

        uint256[] memory availableSubscriptionIds = new uint256[](
            _totalClaimableSubscriptions
        );
        uint256[] memory claimableAmounts = new uint256[](
            _totalClaimableSubscriptions
        );

        for (uint256 i = 0; i < _subscriptionIds.length; i++) {
            if (_isClaimableSubscription(_subscriptionIds[i])) {
                uint256 availableAmount = _getAvailableAmount(
                    _subscriptionIds[i]
                );
                Subscription storage subscription = _subscriptions[
                    _subscriptionIds[i]
                ];
                subscription.vestedAmount += availableAmount;

                availableSubscriptionIds[index] = _subscriptionIds[i];
                claimableAmounts[index] = availableAmount;
                totalClaimableAmount += availableAmount;
                index++;
            }
        }

        if (totalClaimableAmount != 0) {
            erc20Token.safeTransfer(_msgSender(), totalClaimableAmount);
        }

        emit ClaimSucceeded(
            _msgSender(),
            totalClaimableAmount,
            availableSubscriptionIds,
            claimableAmounts
        );
    }

    function _getTotalClaimableSubscriptions(uint256[] memory _subscriptionIds)
        internal
        view
        returns (uint256 count)
    {
        count = 0;
        for (uint256 i = 0; i < _subscriptionIds.length; i++) {
            if (_isClaimableSubscription(_subscriptionIds[i])) {
                count++;
            }
        }
    }

    function _isClaimableSubscription(uint256 _subscriptionId)
        internal
        view
        returns (bool)
    {
        return (_subscriptions[_subscriptionId].wallet == _msgSender() &&
            _subscriptions[_subscriptionId].isActive &&
            _getAvailableAmount(_subscriptionId) != 0);
    }

    function _getAvailableAmount(uint256 _subscriptionId)
        internal
        view
        returns (uint256 availableAmount)
    {
        Subscription memory subscription = _subscriptions[_subscriptionId];
        Scheme memory scheme = subscription.scheme;
        // in case of: have not time for vesting yet
        if (block.timestamp < scheme.startTsTGE || !subscription.isActive) {
            return 0;
        } else if (block.timestamp < subscription.endTs) {
            // in case of: subscription which is claimed
            if (subscription.vestedAmount == subscription.totalVestingAmount) {
                return 0;
            }
            // in case of: unlocked amount at TGE
            if (block.timestamp >= scheme.startTsTGE + scheme.cliffPeriodTGE) {
                availableAmount +=
                    (subscription.totalVestingAmount *
                        scheme.unlockPercentTGE) /
                    ZOOM;
            }

            if (block.timestamp >= scheme.startTsUnlockVesting) {
                uint256 currentDurationTime = block.timestamp -
                    scheme.startTsUnlockVesting;
                uint256 currentPeriod = currentDurationTime / scheme.period + 1;
                uint256 claimableAmount = currentPeriod *
                    subscription.periodVestingAmount;

                availableAmount += claimableAmount;
                availableAmount = availableAmount <= subscription.vestedAmount
                    ? 0
                    : availableAmount - subscription.vestedAmount;
            }

            if (block.timestamp + scheme.period > subscription.endTs) {
                availableAmount =
                    subscription.totalVestingAmount -
                    subscription.vestedAmount;
            }
        } else {
            availableAmount =
                subscription.totalVestingAmount -
                subscription.vestedAmount;
        }
    }
}
