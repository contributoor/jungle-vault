// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

abstract contract YieldStrategy {
    address public immutable id;
    address public immutable underlyingAsset;

    constructor(address _id, address _underlyingAsset) {
        id = _id;
        underlyingAsset = _underlyingAsset;
    }

    function deposit(uint256 amount) external virtual;
    function withdraw(uint256 amount, uint256 shares, uint256 supply) external virtual;
    function withdrawAll() external virtual returns (uint256);
}
