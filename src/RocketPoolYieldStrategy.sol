// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {RocketDAOProtocolSettingsDepositInterface} from
    "lib/rocketpool/contracts/interface/dao/protocol/settings/RocketDAOProtocolSettingsDepositInterface.sol";
import {RocketDepositPoolInterface} from "lib/rocketpool/contracts/interface/deposit/RocketDepositPoolInterface.sol";
import {RocketStorageInterface} from "lib/rocketpool/contracts/interface/RocketStorageInterface.sol";
import {RocketTokenRETHInterface} from "lib/rocketpool/contracts/interface/token/RocketTokenRETHInterface.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import {WETH} from "lib/solmate/src/tokens/WETH.sol";
import {FixedPointMathLib} from "lib/solmate/src/utils/FixedPointMathLib.sol";
import {IUniswapV2Router02} from "lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import {YieldStrategy} from "./interfaces/YieldStrategy.sol";

contract RocketPoolYieldStrategy is YieldStrategy {
    using FixedPointMathLib for uint256;

    RocketStorageInterface internal immutable rocketStorage;
    IUniswapV2Router02 internal immutable uniswapRouter;
    WETH internal immutable weth;

    constructor(address _rocketStorageAddress, address payable _underlyingAsset, address _uniswapRouterAddress)
        YieldStrategy(_rocketStorageAddress, _underlyingAsset)
    {
        rocketStorage = RocketStorageInterface(_rocketStorageAddress);
        uniswapRouter = IUniswapV2Router02(_uniswapRouterAddress);
        weth = WETH(_underlyingAsset);
    }

    function deposit(uint256 assets) external override {
        require(availableDepositCapacity() > assets, "Deposit limit exceeded");

        // @dev unwrap
        weth.withdraw(assets);
        uint256 oldBalance = tokenRETH().balanceOf(address(this));
        rocketDepositPool().deposit{value: assets}();
        uint256 newBalance = tokenRETH().balanceOf(address(this));
        require(newBalance > oldBalance, "No RETH minted");
    }

    function withdraw(uint256, /* assets */ uint256 shares, uint256 supply) external override {
        // @dev calculate proportion of RETH balance to withdraw
        uint256 balance = tokenRETH().balanceOf(address(this));
        uint256 rethToWithdraw = shares.mulDivDown(balance, supply);
        swapRETHForWETH(rethToWithdraw);
    }

    function withdrawAll() external override returns (uint256) {
        uint256 balance = tokenRETH().balanceOf(address(this));
        return swapRETHForWETH(balance);
    }

    /*//////////////////////////////////////////////////////////////
                        ROCKET POOL GETTERS
    //////////////////////////////////////////////////////////////*/

    function rocketDepositProtocol() internal view returns (RocketDAOProtocolSettingsDepositInterface) {
        // @notice upgradeable contract
        address protocolAddress = rocketStorage.getAddress(
            keccak256(abi.encodePacked("contract.address", "rocketDAOProtocolSettingsDeposit"))
        );
        return RocketDAOProtocolSettingsDepositInterface(protocolAddress);
    }

    function rocketDepositPool() internal view returns (RocketDepositPoolInterface) {
        // @notice upgradeable contract
        address poolAddress =
            rocketStorage.getAddress(keccak256(abi.encodePacked("contract.address", "rocketDepositPool")));
        return RocketDepositPoolInterface(poolAddress);
    }

    function tokenRETHAddress() internal view returns (address) {
        // @notice upgradeable contract
        return rocketStorage.getAddress(keccak256(abi.encodePacked("contract.address", "rocketTokenRETH")));
    }

    function tokenRETH() internal view returns (RocketTokenRETHInterface) {
        address rethAddress = tokenRETHAddress();
        return RocketTokenRETHInterface(rethAddress);
    }

    function availableDepositCapacity() internal view returns (uint256) {
        uint256 deposited = rocketDepositPool().getBalance();
        uint256 maxPoolSize = rocketDepositProtocol().getMaximumDepositPoolSize();
        return maxPoolSize - deposited;
    }

    /*//////////////////////////////////////////////////////////////
                        UNISWAP UTILS
    //////////////////////////////////////////////////////////////*/

    function buildSwapPath(address from, address to) internal pure returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = from;
        path[1] = to;
        return path;
    }

    function swapRETHForWETH(uint256 rethAmount) internal returns (uint256) {
        require(ERC20(tokenRETHAddress()).approve(address(uniswapRouter), rethAmount), "Uniswap approval failed");

        uint256 oldWETHBalance = weth.balanceOf(address(this));
        address[] memory swapPath = buildSwapPath(tokenRETHAddress(), id);
        uniswapRouter.swapExactTokensForTokens(rethAmount, 0, swapPath, address(this), block.timestamp);
        uint256 newWETHBalance = weth.balanceOf(address(this));

        require(newWETHBalance > oldWETHBalance, "No WETH swapped");
        return newWETHBalance - oldWETHBalance;
    }
}
