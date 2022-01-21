// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (finance/PaymentSplitter.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title TokenSplitter
 * @dev This contract is a modification of PaymentSplitter from OpenZeppelin.  It removes the logic/events for splitting
 * ETH and extends the contract with a TIMELOCK that allows Owner to sweep ERC20 tokens after expiration.  I've added
 * 3 new functions - initializer(), sweepEth(), & sweepTokensAndPause().  Additional code is flagged with comments
 * while the unused OpenZeppelin code is commented out.
 *
 * @notice NOT FOR USE IN PRODUCTION - REQUIRES FURTHER TESTING
 */

/**
 * @title PaymentSplitter
 * @dev This contract allows to split Ether payments among a group of accounts. The sender does not need to be aware
 * that the Ether will be split in this way, since it is handled transparently by the contract.
 *
 * The split can be in equal parts or in any other arbitrary proportion. The way this is specified is by assigning each
 * account to a number of shares. Of all the Ether that this contract receives, each account will then be able to claim
 * an amount proportional to the percentage of total shares they were assigned.
 *
 * `PaymentSplitter` follows a _pull payment_ model. This means that payments are not automatically forwarded to the
 * accounts but kept in this contract, and the actual transfer is triggered as a separate step by calling the {release}
 * function.
 *
 * NOTE: This contract assumes that ERC20 tokens will behave similarly to native tokens (Ether). Rebasing tokens, and
 * tokens that apply fees during transfers, are likely to not be supported as expected. If in doubt, we encourage you
 * to run tests before sending real value to this contract.
 */
contract Splitter is Context, Pausable {
    event PayeeAdded(address account, uint256 shares);
    event PaymentReleased(address to, uint256 amount);
    event ERC20PaymentReleased(
        IERC20 indexed token,
        address to,
        uint256 amount
    );
    event PaymentReceived(address from, uint256 amount);

    // ~~~~THIS IS NEW CODE~~~~
    IERC20 private token;
    address public owner;
    uint256 private constant TIMELOCK = 1 minutes; //will change to X days before deploy.  Need to ask community.
    uint256 private start; //records block.timestamp at deployment for use with TIMELOCK
    bool private initialized;
    //~~~~~~~~~~~~~~~~~~~~~~~~~~

    uint256 private _totalShares;
    uint256 private _totalReleased;

    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;
    address[] private _payees;

    mapping(IERC20 => uint256) private _erc20TotalReleased;
    mapping(IERC20 => mapping(address => uint256)) private _erc20Released;

    /**
     * @dev Creates an instance of `PaymentSplitter` where each account in `payees` is assigned the number of shares at
     * the matching position in the `shares` array.
     *
     * All addresses in `payees` must be non-zero. Both arrays must have the same non-zero length, and there must be no
     * duplicates in `payees`.
     *
     * ~~~~Remember to fund contract with DAI after deployment~~~~~
     */
    constructor(
        address[] memory payees,
        uint256[] memory shares_,
        IERC20 _paymentToken
    ) payable {
        require(
            payees.length == shares_.length,
            "PaymentSplitter: payees and shares length mismatch"
        );
        require(payees.length > 0, "PaymentSplitter: no payees");
        require(
            address(_paymentToken) != address(0),
            "PaymentSplitter: IERC20 Address cannot be zero"
        );

        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares_[i]);
        }

        token = _paymentToken;
        owner = payable(msg.sender);
        start = block.timestamp;

        _pause();
        //fund contract with DAI & call initialize() to open contract
    }

    //Modifiers
    //  ~~~~~~~~~~~~NEW CODE~~~~~~~~~~~~~~~~~~~~~~~~~~~
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner may call this function.");
        _;
    }

    modifier notLocked() {
        require(block.timestamp >= start + TIMELOCK, "Function is timelocked");
        _;
    }

    /**
     * @dev This function should be called after funding the contract.  The token balance of contract MUST
     * be equal to _totalShares or the shares/balances owed percentages become skewed and disrupt token balances.
     * @dev If there is an overage in funding (more tokens than totalShares) then the difference is returned to
     * owner.  Contract is unpaused once _contractBalance is equal to totalShares.
     */
    function initialize() external onlyOwner {
        require(
            initialized == false,
            "PaymentSplitter: Contract has already been initialized."
        );
        uint256 _contractBalance = token.balanceOf(address(this));

        if (_contractBalance < totalShares()) {
            //Revert if contract balance < _totalShares
            revert(
                "Add more tokens to make shares and contract balance equal."
            );
        } else if (_contractBalance > totalShares()) {
            //Return overage to owner & unpause
            initialized = true;
            uint256 overage = _contractBalance - totalShares();
            SafeERC20.safeTransfer(token, owner, overage);
            _unpause();
        } else {
            initialized = true;
            _unpause(); //_contractBalance == totalShares()
        }
    }

    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~END NEW CODE BLOCK~~~~~~~~~~~~~~~~~~~~~~~~~~

    /**
     * @dev The Ether received will be logged with {PaymentReceived} events. Note that these events are not fully
     * reliable: it's possible for a contract to receive Ether without triggering this function. This only affects the
     * reliability of the events, and not the actual splitting of Ether.
     *
     * To learn more about this see the Solidity documentation for
     * https://solidity.readthedocs.io/en/latest/contracts.html#fallback-function[fallback
     * functions].
     */
    receive() external payable virtual {
        emit PaymentReceived(_msgSender(), msg.value);
    }

    /**
     * @dev Getter for the total shares held by payees.
     */
    function totalShares() public view returns (uint256) {
        return _totalShares;
    }

    /**
     * @dev Getter for the total amount of Ether already released.
     */
    // function totalReleased() public view returns (uint256) {
    //     return _totalReleased;
    // }

    /**
     * @dev Getter for the total amount of `token` already released. `token` should be the address of an IERC20
     * contract.
     */
    function totalReleased() public view returns (uint256) {
        return _erc20TotalReleased[token];
    }

    /**
     * @dev Getter for the amount of shares held by an account.
     */
    function shares(address account) public view returns (uint256) {
        return _shares[account];
    }

    /**
     * @dev Getter for the amount of Ether already released to a payee.
     */
    // function released(address account) public view returns (uint256) {
    //     return _released[account];
    // }

    /**
     * @dev Getter for the amount of `token` tokens already released to a payee. `token` should be the address of an
     * IERC20 contract.
     */
    function released(address account) public view returns (uint256) {
        return _erc20Released[token][account];
    }

    /**
     * @dev Getter for the address of the payee number `index`.
     */
    function payee(uint256 index) public view returns (address) {
        return _payees[index];
    }

    /**
     * @dev Triggers a transfer to `account` of the amount of Ether they are owed, according to their percentage of the
     * total shares and their previous withdrawals.
     */
    // function release(address payable account) public virtual {
    //     require(_shares[account] > 0, "PaymentSplitter: account has no shares");

    //     uint256 totalReceived = address(this).balance + totalReleased();
    //     uint256 payment = _pendingPayment(account, totalReceived, released(account));

    //     require(payment != 0, "PaymentSplitter: account is not due payment");

    //     _released[account] += payment;
    //     _totalReleased += payment;

    //     Address.sendValue(account, payment);
    //     emit PaymentReleased(account, payment);
    // }

    /**
     * @dev Triggers a transfer to `account` of the amount of `token` tokens they are owed, according to their
     * percentage of the total shares and their previous withdrawals. `token` must be the address of an IERC20
     * contract.
     */
    function release(address account) public virtual whenNotPaused {
        require(_shares[account] > 0, "PaymentSplitter: account has no shares");

        uint256 totalReceived = token.balanceOf(address(this)) +
            totalReleased();
        uint256 payment = _pendingPayment(
            account,
            totalReceived,
            released(account)
        );

        require(payment != 0, "PaymentSplitter: account is not due payment");

        _erc20Released[token][account] += payment;
        _erc20TotalReleased[token] += payment;

        SafeERC20.safeTransfer(token, account, payment);
        emit ERC20PaymentReleased(token, account, payment);
    }

    /**
     * @dev internal logic for computing the pending payment of an `account` given the token historical balances and
     * already released amounts.
     */
    function _pendingPayment(
        address account,
        uint256 totalReceived,
        uint256 alreadyReleased
    ) private view returns (uint256) {
        return
            (totalReceived * _shares[account]) / _totalShares - alreadyReleased;
    }

    /**
     * @dev Add a new payee to the contract.
     * @param account The address of the payee to add.
     * @param shares_ The number of shares owned by the payee.
     */
    function _addPayee(address account, uint256 shares_) private {
        require(
            account != address(0),
            "PaymentSplitter: account is the zero address"
        );
        require(shares_ > 0, "PaymentSplitter: shares are 0");
        require(
            _shares[account] == 0,
            "PaymentSplitter: account already has shares"
        );

        _payees.push(account);
        _shares[account] = shares_;
        _totalShares = _totalShares + shares_;
        emit PayeeAdded(account, shares_);
    }

    /**
     *  ~~~~~~~~~~~~~~THIS IS NEW CODE~~~~~~~~~~~~~~~~~
     * @dev Allocates remaining shares to Owner and transfers all ERC20 tokens to Owner. This DOES NOT
     * remove shares from payees - which enables SONE to track funds not withdrawn. We can track with events
     * as well if we want to change this.
     * @dev Contract is paused forever after this call.
     * @notice Allows owner to withdraw all ERC20 tokens.  This function is TIMELOCKED for 3 days after deployment.
     */
    function sweepTokensAndPause() external onlyOwner notLocked {
        _shares[owner] = token.balanceOf(address(this));
        release(owner);
        _pause();
        //withdrawals are paused after this call
    }

    /**
     * @dev If ETH is erroneously sent to the contract sweepEth() allows Owner to sweep it
     */
    function sweepEth() external onlyOwner {
        require(address(this).balance > 0, "No ETH to sweep");

        (bool sent, bytes memory data) = owner.call{
            value: address(this).balance
        }("");
        require(sent, "Failed to send Ether");
    }
    //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~END NEW CODE BLOCK~~~~~~~~~~~~~~~~~~~~~~~~~~
}
