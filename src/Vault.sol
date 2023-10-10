// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Auth} from "lib/solmate/src/auth/Auth.sol";
import {ERC4626} from "lib/solmate/src/mixins/ERC4626.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";

import {YieldStrategy} from "./interfaces/YieldStrategy.sol";

contract Vault is ERC4626, Auth {
    YieldStrategy public activeStrategy;

    event StrategyUpdate(YieldStrategy indexed strategy);
    event Deposit(address indexed from, YieldStrategy indexed strategy, uint256 assets);
    event Withdrawal(
        address indexed from, YieldStrategy indexed strategy, uint256 assets, uint256 shares, uint256 totalSupply
    );

    constructor(ERC20 _asset, YieldStrategy _initialStrategy)
        ERC4626(
            _asset,
            string(abi.encodePacked("Jungle ", _asset.name(), "Vault")),
            string(abi.encodePacked("jv", _asset.symbol()))
        )
        Auth(Auth(msg.sender).owner(), Auth(msg.sender).authority())
    {
        activeStrategy = _initialStrategy;
    }

    receive() external payable {}

    function setStrategy(YieldStrategy newStrategy) external requiresAuth {
        uint256 balance = activeStrategy.withdrawAll();
        newStrategy.deposit(balance);
        activeStrategy = newStrategy;
        emit StrategyUpdate(activeStrategy);
    }

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function afterDeposit(uint256 assets, uint256 /* shares */ ) internal override {
        activeStrategy.deposit(assets);
        emit Deposit(msg.sender, activeStrategy, assets);
    }

    function beforeWithdraw(uint256 assets, uint256 shares) internal override {
        activeStrategy.withdraw(assets, shares, totalSupply);
        emit Withdrawal(msg.sender, activeStrategy, assets, shares, totalSupply);
    }
}
