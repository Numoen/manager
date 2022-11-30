pragma solidity ^0.8.4;

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { LendgineAddress } from "numoen-core/libraries/LendgineAddress.sol";

import { MockERC20 } from "./utils/mocks/MockERC20.sol";

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

contract DeployTest is Test {
    MockERC20 public immutable base;
    MockERC20 public immutable speculative;

    uint256 public immutable upperBound = 5 ether;

    Factory public factory;
    Lendgine public lendgine;
    Pair public pair;

    constructor() {
        base = new MockERC20();
        speculative = new MockERC20();
    }

    function testDeploy() public {
        factory = new Factory();
        (address _lendgine, address _pair) = factory.createLendgine(
            address(base),
            address(speculative),
            18,
            18,
            upperBound
        );

        address lendgineEstimate = LendgineAddress.computeLendgineAddress(
            address(factory),
            address(base),
            address(speculative),
            18,
            18,
            upperBound
        );

        address pairEstimate = LendgineAddress.computePairAddress(
            address(factory),
            address(base),
            address(speculative),
            18,
            18,
            upperBound
        );

        assertEq(_lendgine, lendgineEstimate);
        assertEq(_pair, pairEstimate);
    }
}
