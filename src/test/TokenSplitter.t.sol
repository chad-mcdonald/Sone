pragma solidity 0.8.6;
// SPDX-License-Identifier: MIT


import "lib/ds-test/src/test.sol";
import "src/TokenSplitter.sol";
import "src/Dai.sol";
import "lib/console.sol";
import { Hevm } from "lib/hevm/src/Hevm.sol";

contract HevmExampleTest is Hevm, DSTest {
  function testDeal() public {
    address usr = 0x000000000000000000000000000000000000dEaD;
    hevm.deal(usr, 500 ether);
    assertEq(usr.balance, 500 ether);
  }
}

contract User {

}

contract SplitterTest is DSTest {
    User user;
    TokenSplitter tokenSplitter;
    Dai dai;

    address[] payees = [0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
                        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
                        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
                        0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB,
                        0x617F2E2fD72FD9D5503197092aC168c91465E7f2];

    uint256[] shares = [495,4098,5115,199,92];

    function setUp() public {
      dai = new Dai();
      console.log("Dai Contract Address: ", address(dai));
      IERC20 paymentToken = IERC20(dai);
      user = new User();
      }

}