// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;
imp

contract Router {

  address immutable private factory;

  constructor(address _factory) {
    factory = _factory;
  }

    function mint(
        uint256 amount,
        address tokenIn,
        address speculative,
        address base,
        uint256 upperBound
    ) public {
      

      // (uint256 nlpBalance0, uint256 nlpBalance1) = 
    }
}
