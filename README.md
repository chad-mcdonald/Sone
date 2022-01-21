# Sone
## Smart Contracts for use by the Sone DAO

This is the repo where [Sone](https://sone.works/) Smart contracts live.  

## TokenSplitter.sol

:exclamation: Not for use in production :exclamation:


This is Sone's payment distribution contract.  It is a modification of PaymentSplitter from OpenZeppelin.  It removes the logic/events for splitting ETH and extends the contract with a TIMELOCK that allows Owner to sweep ERC20 tokens after expiration.  There are 3 new functions - initializer(), sweepEth(), & sweepTokensAndPause() - which are described in the code comments.  Additional code is flagged with comments while the unused OpenZeppelin code is commented out.  

TokenSplitter is a work in progress and testing is the next step :thumbsup:	
