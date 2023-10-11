// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {YieldStrategy} from "./YieldStrategy.sol";

// @dev to be inherited in both Vault contract and its tests
// https://ethereum.stackexchange.com/a/148530
interface VaultEvents {
    event StrategyUpdate(YieldStrategy indexed strategy);
    event Deposit(address indexed from, YieldStrategy indexed strategy, uint256 assets);
    event Withdrawal(
        address indexed from, YieldStrategy indexed strategy, uint256 assets, uint256 shares, uint256 totalSupply
    );
}
