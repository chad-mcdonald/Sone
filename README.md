# Sone
## Smartcontracts

This is the repo where the contracts for [SoneDAO](https://sone.works/) live.  

## TokenSplitter.sol :exclamation: Not for use in production :exclamation:

TokenSplitter is Sone's payment distribution contract.  It allows artist's to withdraw streaming royalties (paid in a stablecoin) during a 3 day withdrawal window.


TokenSplitter is a modification of [PaymentSplitter](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/finance/PaymentSplitter.sol) from OpenZeppelin.  It removes the logic/events for splitting ETH and extends the contract with a TIMELOCK that allows Owner to sweep ERC20 tokens after expiration.


### There are 3 new functions: initializer(), sweepEth(), & sweepTokensAndPause()


`initializer()` - MUST be called to unpause contract and open up withdrawals.  Before unpausing the contract, initializer() requires the balance of stablecoin and the amount of shares owed to be strictly equal.

`sweepEth()` - Allows owner to withdraw any ETH erroneously sent to the contract.

`sweepTokensAndPause()` - This function is timelocked for 3 days once initializer() is sucessfully called.  Once the timelock has expired, owner may call this to withdraw remaining tokens.  Contract is paused forever after this is called.

### Notes

Additional code is flagged with comments and the removed OpenZeppelin code is commented out.  

TokenSplitter is a work in progress and testing is the next step :thumbsup:	
