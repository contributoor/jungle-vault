// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "../../lib/solmate/src/utils/SafeTransferLib.sol";

import {YieldStrategy} from "../../src/interfaces/YieldStrategy.sol";

contract MockYieldStrategy is YieldStrategy {
    using SafeTransferLib for ERC20;

    constructor(address _id, address _underlyingAsset) YieldStrategy(_id, _underlyingAsset) {}

    function deposit(uint256 amount) public override {
        ERC20(underlyingAsset).safeTransferFrom(msg.sender, address(this), amount);
        ERC20(underlyingAsset).safeApprove(id, amount);
        MockPool(id).stake(amount);
    }

    function withdraw(uint256 amount, uint256, /* shares */ uint256 /* supply */ ) public override {
        MockPool(id).unstake(amount);
    }

    function withdrawAll() public override returns (uint256) {
        return MockPool(id).unstakeAll();
    }
}

contract MockRevertingYieldStrategy is YieldStrategy {
    constructor(address _id, address _underlyingAsset) YieldStrategy(_id, _underlyingAsset) {}

    function deposit(uint256) public pure override {
        revert();
    }

    function withdraw(uint256, uint256, uint256) public pure override {
        revert();
    }

    function withdrawAll() public pure override returns (uint256) {
        revert();
    }
}

contract MockPool {
    using SafeTransferLib for ERC20;

    ERC20 public underlyingAsset;

    constructor(ERC20 _underlyingAsset) {
        underlyingAsset = _underlyingAsset;
    }

    function stake(uint256 amount) external {
        underlyingAsset.safeTransferFrom(msg.sender, address(this), amount);
    }

    function unstake(uint256 amount) external {
        require(amount <= underlyingAsset.balanceOf(address(this)), "Insufficient balance");
        underlyingAsset.safeTransfer(msg.sender, amount);
    }

    function unstakeAll() external returns (uint256) {
        uint256 toUnstake = underlyingAsset.balanceOf(address(this));
        underlyingAsset.safeTransfer(msg.sender, toUnstake);
        return toUnstake;
    }
}
