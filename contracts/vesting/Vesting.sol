// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Vesting is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;
    using Counters for Counters.Counter;

    struct Scheme {
        string name;
        // the length of the period when no token is released, in seconds
        uint256 cliffPeriod;
        // epoch start timestamp, in seconds
        uint256 startTs;
        // epoch end timestamp, in seconds
        uint256 endTs;
        // the length of the whole vesting scheme, in seconds
        uint256 duration;
        // the length of time for each period, in seconds
        uint256 period;
        bool isActive;
    }

    struct Subscription {
        uint256 schemeId;
        address wallet;
        uint256 cliffPeriod;
        uint256 startTs;
        uint256 duration;
        uint256 endTs;
        uint256 period;
        uint256 totalVestingAmount;
        uint256 periodVestingAmount;
        uint256 vestedAmount;
        bool isActive;
    }

    IERC20 public erc20Token;
    Counters.Counter public schemeCount;
    Counters.Counter public subscriptionCount;
    address public emergencyWallet;
    //@dev epoch time and in seconds
    uint256 public tge;
    mapping(uint256 => Scheme) private _schemes;
    mapping(uint256 => Subscription) private _subscriptions;
    mapping(address => uint256[]) private _participatedSubscriptionIDs;
    mapping(address => bool) private _operators;

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
        uint256 cliffTime,
        uint256 startTime,
        uint256 durationTime,
        uint256 endTime,
        uint256 periodTime,
        bool isActive
    );
    event SchemeUpdated(
        uint256 schemeId,
        string name,
        uint256 cliffTime,
        uint256 startTime,
        uint256 durationTime,
        uint256 endTime,
        uint256 periodTime
    );
    event SchemeActivated(uint256 schemeId, bool isActive);
    event SubscriptionAdded(
        uint256 vestingId,
        uint256 schemeId,
        address wallet,
        uint256 cliffTime,
        uint256 startTime,
        uint256 durationTime,
        uint256 periodTime,
        uint256 totalVestingAmount,
        uint256 vestedAmount,
        uint256 depositAmount,
        bool isActive
    );
    event SubscriptionDisabled(uint256 vestingId);
    event ClaimSucceeded(
        address wallet,
        uint256[] vestingIds,
        uint256[] claimableAmounts,
        uint256 totalClaimableAmount
    );
    event VestingContractConfigured(address erc20Contract);
    event EmergencyWalletConfigured(address emergencyWallet);
    event EmergencyWithdrawalExecuted(address emergencyWallet, uint256 amount);
    event OperatorAdded(address operator, bool isOperator);
    event TokenGenerationEventConfigured(uint256 time);

    modifier onlyOperator() {
        _onlyOperator();
        _;
    }

    modifier schemeExist(uint256 schemeId) {
        _schemeExist(schemeId);
        _;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
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

    function setOperator(address operator, bool isOperator_) public onlyOwner {
        _operators[operator] = isOperator_;
        emit OperatorAdded(operator, isOperator_);
    }

    function setTGE(uint256 time) external onlyOwner {
        require(tge == 0, "Can only be initialized once");
        require(time > 0, "Time must be greater than zero");
        tge = time;
        emit TokenGenerationEventConfigured(tge);
    }

    function addScheme(
        string memory name,
        uint256 cliffPeriod,
        uint256 startTs,
        uint256 duration,
        uint256 period
    ) external onlyOperator {
        startTs = _checkSchemeInfo(
            name,
            cliffPeriod,
            startTs,
            duration,
            period
        );

        schemeCount.increment();
        uint256 schemeId = schemeCount.current();
        Scheme storage scheme = _schemes[schemeId];
        scheme.name = name;
        scheme.cliffPeriod = cliffPeriod;
        scheme.startTs = startTs;
        scheme.duration = duration;
        scheme.period = period;
        scheme.endTs = startTs + duration;
        scheme.isActive = true;

        emit SchemeCreated(
            schemeId,
            scheme.name,
            scheme.cliffPeriod,
            scheme.startTs,
            scheme.duration,
            scheme.endTs,
            scheme.period,
            scheme.isActive
        );
    }

    function updateScheme(
        uint256 schemeId,
        string memory name,
        uint256 cliffPeriod,
        uint256 startTs,
        uint256 duration,
        uint256 period
    ) external onlyOperator schemeExist(schemeId) {
        startTs = _checkSchemeInfo(
            name,
            cliffPeriod,
            startTs,
            duration,
            period
        );

        Scheme storage scheme = _schemes[schemeId];
        scheme.name = name;
        scheme.cliffPeriod = cliffPeriod;
        scheme.startTs = startTs;
        scheme.duration = duration;
        scheme.period = period;
        scheme.endTs = startTs + duration;

        emit SchemeUpdated(
            schemeId,
            scheme.name,
            scheme.cliffPeriod,
            scheme.startTs,
            scheme.duration,
            scheme.endTs,
            scheme.period
        );
    }

    function toggleSchemeActivation(uint256 schemeId, bool isActive)
        external
        onlyOperator
        schemeExist(schemeId)
    {
        _schemes[schemeId].isActive = isActive;
        emit SchemeActivated(schemeId, isActive);
    }

    function addSubscription(
        uint256 schemeId,
        address wallet,
        uint256 startTs,
        uint256 totalVestingAmount,
        uint256 vestedAmount,
        uint256 depositAmount
    ) public onlyOperator schemeExist(schemeId) {
        require(_schemes[schemeId].isActive, "Scheme is not active");
        require(
            totalVestingAmount > 0,
            "Total vesting amount must be greater than zero"
        );
        if (startTs > 0) {
            require(startTs >= tge, "Start timestamp must be greater than TGE");
        }
        require(
            vestedAmount < totalVestingAmount,
            "Vested amount must be less than total vesting amount"
        );

        Scheme memory scheme = _schemes[schemeId];
        subscriptionCount.increment();

        uint256 vestingId = subscriptionCount.current();
        _participatedSubscriptionIDs[wallet].push(vestingId);

        Subscription storage subscription = _subscriptions[vestingId];
        subscription.schemeId = schemeId;
        subscription.wallet = wallet;
        subscription.cliffPeriod = scheme.cliffPeriod;
        subscription.startTs = startTs == 0
            ? scheme.startTs
            : startTs + subscription.cliffPeriod;
        subscription.duration = scheme.duration;
        subscription.endTs = subscription.startTs + subscription.duration;
        subscription.period = scheme.period;
        subscription.totalVestingAmount = totalVestingAmount;
        uint256 vestingCount_ = subscription.duration / subscription.period;
        subscription.periodVestingAmount = totalVestingAmount / vestingCount_;
        subscription.vestedAmount = vestedAmount;
        subscription.isActive = true;

        {
            // Deposit token for vesting plan
            if (depositAmount > 0) {
                require(
                    depositAmount == totalVestingAmount - vestedAmount,
                    "Deposit amount must be equal to remaining vesting amount"
                );
                erc20Token.safeTransferFrom(
                    _msgSender(),
                    address(this),
                    depositAmount
                );
            }
        }

        emit SubscriptionAdded(
            vestingId,
            schemeId,
            wallet,
            subscription.cliffPeriod,
            subscription.startTs,
            subscription.duration,
            subscription.period,
            subscription.totalVestingAmount,
            subscription.vestedAmount,
            depositAmount,
            subscription.isActive
        );
    }

    function addSubscriptions(
        uint256[] memory schemeIds,
        address[] memory wallets,
        uint256[] memory startTimes,
        uint256[] memory totalVestingAmounts,
        uint256[] memory vestedAmounts,
        uint256 depositAmount
    ) external onlyOperator {
        require(wallets.length > 0, "Requiring at least one account address");
        require(
            wallets.length == schemeIds.length,
            "Account and scheme lists must have the same length"
        );
        require(
            wallets.length == startTimes.length,
            "Account and start time lists must have the same length"
        );
        require(
            wallets.length == totalVestingAmounts.length,
            "Account and total vesting amount lists must have the same length"
        );
        require(
            wallets.length == vestedAmounts.length,
            "Account and vested amount lists must have the same length"
        );
        uint256[] memory depositAmounts = new uint256[](
            totalVestingAmounts.length
        );
        if (depositAmount > 0) {
            uint256 totalDepositAmount;
            for (uint256 i = 0; i < totalVestingAmounts.length; i++) {
                depositAmounts[i] = totalVestingAmounts[i] - vestedAmounts[i];
                totalDepositAmount += depositAmounts[i];
            }
            require(
                depositAmount == totalDepositAmount,
                "Deposit amount must be equal to remaining vesting amount"
            );
        }
        for (uint256 i = 0; i < wallets.length; i++) {
            addSubscription(
                schemeIds[i],
                wallets[i],
                startTimes[i],
                totalVestingAmounts[i],
                vestedAmounts[i],
                depositAmounts[i]
            );
        }
    }

    //@dev this function allows an user to claim all amount available at present in subscriptionID of subscriptions[]
    function claim(uint256[] memory subscriptionIDs)
        external
        nonReentrant
        whenNotPaused
    {
        require(
            subscriptionIDs.length > 0,
            "Requiring at least one subscription ID"
        );

        uint256 totalClaimableSubscriptions = _getTotalClaimableSubscriptions(
            subscriptionIDs
        );
        _claim(subscriptionIDs, totalClaimableSubscriptions);
    }

    //@dev this function allows an user claim  all available amount in schemes that the user's currently participating
    function claimAll() external nonReentrant whenNotPaused {
        uint256 totalClaimableSubscriptions = _getTotalClaimableSubscriptions(
            _participatedSubscriptionIDs[_msgSender()]
        );
        _claim(
            _participatedSubscriptionIDs[_msgSender()],
            totalClaimableSubscriptions
        );
    }

    function disableVesting(uint256 vestingId) external onlyOperator {
        require(
            vestingId >= 1 && vestingId <= subscriptionCount.current(),
            "Vesting Id is invalid"
        );
        Subscription storage vesting = _subscriptions[vestingId];
        vesting.isActive = false;

        emit SubscriptionDisabled(vestingId);
    }

    function isOperator(address operator) external view returns (bool) {
        return _operators[operator];
    }

    function getParticipatedSubscriptionIDs(address wallet)
        external
        view
        returns (uint256[] memory)
    {
        return _participatedSubscriptionIDs[wallet];
    }

    function getAvailableAmount(address wallet)
        external
        view
        returns (uint256 totalVestingAmount, uint256 availableAmount)
    {
        uint256[] memory subscriptionIDs = _participatedSubscriptionIDs[wallet];

        for (uint256 i = 0; i < subscriptionIDs.length; i++) {
            if (_subscriptions[subscriptionIDs[i]].isActive) {
                totalVestingAmount += _subscriptions[subscriptionIDs[i]]
                    .totalVestingAmount;
                availableAmount += _getAvailableAmount(subscriptionIDs[i]);
            }
        }
    }

    function getScheme(uint256 schemeId)
        external
        view
        returns (
            string memory name,
            uint256 cliffTime,
            uint256 startTime,
            uint256 durationTime,
            uint256 endTime,
            uint256 periodTime,
            bool isActive
        )
    {
        Scheme memory scheme = _schemes[schemeId];
        name = scheme.name;
        cliffTime = scheme.cliffPeriod;
        startTime = scheme.startTs;
        durationTime = scheme.duration;
        endTime = scheme.endTs;
        periodTime = scheme.period;
        isActive = scheme.isActive;
    }

    function getSubscription(uint256 vestingId)
        external
        view
        returns (
            uint256 schemeId,
            address wallet,
            uint256 cliffTime,
            uint256 startTime,
            uint256 durationTime,
            uint256 endTime,
            uint256 periodTime,
            uint256 totalVestingAmount,
            uint256 periodVestingAmount,
            uint256 vestedAmount,
            uint256 availableAmount,
            bool isActive
        )
    {
        Subscription memory vesting = _subscriptions[vestingId];
        schemeId = vesting.schemeId;
        wallet = vesting.wallet;
        cliffTime = vesting.cliffPeriod;
        startTime = vesting.startTs;
        durationTime = vesting.duration;
        endTime = vesting.endTs;
        periodTime = vesting.period;
        totalVestingAmount = vesting.totalVestingAmount;
        periodVestingAmount = vesting.periodVestingAmount;
        vestedAmount = vesting.vestedAmount;
        availableAmount = _getAvailableAmount(vestingId);
        isActive = vesting.isActive;
    }

    function emergencyWithdraw() external whenPaused onlyOwner {
        require(
            emergencyWallet != address(0),
            "Emergency wallet have not set yet"
        );
        uint256 balanceOfThis = erc20Token.balanceOf(address(this));
        if (balanceOfThis > 0) {
            erc20Token.safeTransfer(emergencyWallet, balanceOfThis);
        }
        emit EmergencyWithdrawalExecuted(emergencyWallet, balanceOfThis);
    }

    function _claim(
        uint256[] memory _subscriptionIDs,
        uint256 _totalClaimableSubscriptions
    ) internal {
        uint256 index = 0;
        uint256 totalClaimableAmount = 0;

        uint256[] memory availableSubscriptionIDs = new uint256[](
            _totalClaimableSubscriptions
        );
        uint256[] memory claimableAmounts = new uint256[](
            _totalClaimableSubscriptions
        );

        for (uint256 i = 0; i < _subscriptionIDs.length; i++) {
            if (_isClaimableSubscription(_subscriptionIDs[i])) {
                uint256 availableAmount = _getAvailableAmount(
                    _subscriptionIDs[i]
                );
                Subscription storage vesting = _subscriptions[
                    _subscriptionIDs[i]
                ];
                vesting.vestedAmount += availableAmount;

                availableSubscriptionIDs[index] = _subscriptionIDs[i];
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
            availableSubscriptionIDs,
            claimableAmounts,
            totalClaimableAmount
        );
    }

    function _getTotalClaimableSubscriptions(uint256[] memory _subscriptionIDs)
        internal
        view
        returns (uint256 count)
    {
        count = 0;
        for (uint256 i = 0; i < _subscriptionIDs.length; i++) {
            if (_isClaimableSubscription(_subscriptionIDs[i])) {
                count++;
            }
        }
    }

    function _isClaimableSubscription(uint256 _subscriptionID)
        internal
        view
        returns (bool)
    {
        return (_subscriptions[_subscriptionID].wallet == _msgSender() &&
            _subscriptions[_subscriptionID].isActive &&
            _getAvailableAmount(_subscriptionID) != 0);
    }

    function _getAvailableAmount(uint256 _vestingId)
        internal
        view
        returns (uint256 availableAmount)
    {
        Subscription memory vesting = _subscriptions[_vestingId];
        if (block.timestamp < vesting.startTs || !vesting.isActive) {
            availableAmount = 0;
        } else if (block.timestamp < vesting.endTs) {
            if (vesting.vestedAmount == vesting.totalVestingAmount) {
                return 0;
            }
            uint256 currentDurationTime = block.timestamp - vesting.startTs;
            uint256 currentPeriod = currentDurationTime / vesting.period + 1;
            uint256 claimableAmount = currentPeriod *
                vesting.periodVestingAmount;

            availableAmount = claimableAmount <= vesting.vestedAmount
                ? 0
                : claimableAmount - vesting.vestedAmount;
            if (block.timestamp + vesting.period > vesting.endTs) {
                availableAmount =
                    vesting.totalVestingAmount -
                    vesting.vestedAmount;
            }
        } else {
            availableAmount = vesting.totalVestingAmount - vesting.vestedAmount;
        }
    }

    function _onlyOperator() private view {
        require(_operators[_msgSender()], "Vesting: Sender is not operator");
    }

    function _schemeExist(uint256 schemeId) private view {
        require(
            schemeId >= 1 && schemeId <= schemeCount.current(),
            "Scheme is not exist"
        );
    }

    function _checkSchemeInfo(
        string memory name,
        uint256 cliffPeriod,
        uint256 startTs,
        uint256 duration,
        uint256 period
    ) private view returns (uint256) {
        require(bytes(name).length > 0, "Name must not be empty");
        require(tge != 0, "Have not set tge");

        startTs = startTs == 0 ? tge : startTs;
        require(startTs >= tge, "Start timestamp must be greater than TGE");

        startTs += cliffPeriod;
        require(duration > 0, "Duration must be greater than zero");
        require(
            period > 0 && period <= duration,
            "Period must be greater than zero and less than or equal to duration"
        );
        require(duration % period == 0, "Duration must be divisible by period");

        return startTs;
    }
}
