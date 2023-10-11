// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Owned} from "lib/solmate/src/auth/Owned.sol";
import {ERC4626} from "lib/solmate/src/mixins/ERC4626.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "lib/solmate/src/utils/SafeTransferLib.sol";

import {VaultEvents} from "./interfaces/VaultEvents.sol";
import {YieldStrategy} from "./interfaces/YieldStrategy.sol";

contract Vault is ERC4626, Owned, VaultEvents {
    using SafeTransferLib for ERC20;

    YieldStrategy public activeStrategy;

    constructor(ERC20 _asset, YieldStrategy _initialStrategy)
        ERC4626(
            _asset,
            string(abi.encodePacked("Jungle ", _asset.name(), "Vault")),
            string(abi.encodePacked("jv", _asset.symbol()))
        )
        Owned(msg.sender)
    {
        activeStrategy = _initialStrategy;
    }

    receive() external payable {}

    function setStrategy(YieldStrategy newStrategy) external onlyOwner {
        uint256 balance = activeStrategy.withdrawAll();
        newStrategy.deposit(balance);
        activeStrategy = newStrategy;
        emit StrategyUpdate(activeStrategy);
    }

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function afterDeposit(uint256 assets, uint256 /* shares */ ) internal override {
        ERC20(activeStrategy.underlyingAsset()).safeApprove(address(activeStrategy), assets);
        activeStrategy.deposit(assets);
        emit Deposit(msg.sender, activeStrategy, assets);
    }

    function beforeWithdraw(uint256 assets, uint256 shares) internal override {
        activeStrategy.withdraw(assets, shares, totalSupply);
        emit Withdrawal(msg.sender, activeStrategy, assets, shares, totalSupply);
    }
}
