// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ISGMX} from "./ISGMX.sol";
import {Errors} from "../utils/Errors.sol";
import {ERC4626} from "../utils/ERC4626.sol";
import {Pausable} from "../utils/Pausable.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IRewardRouter} from "./IRewardRouter.sol";
import {ISwapRouter} from "../utils/ISwapRouter.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";


contract GMXVault is ERC4626, Pausable {
    using FixedPointMathLib for uint256;

    /* -------------------------------------------------------------------------- */
    /*                               STATE VARIABLES                              */
    /* -------------------------------------------------------------------------- */

    /// @notice harvest fee
    uint public immutable harvestFee;

    /// @notice Uniswap router
    ISwapRouter public constant uniswapRouter = ISwapRouter(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);

    /// @notice WETH
    IERC20 public constant WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);

    /// @notice Staked + bonus GMX
    ISGMX public constant SBFGMX = ISGMX(0xd2D1162512F927a7e282Ef43a362659E4F2a728F);

    /// @notice Staked gmx
    ISGMX public constant SGMX = ISGMX(0x908C4D94D34924765f1eDc22A1DD098397c59dD4);

    /// @notice gmx reward router
    IRewardRouter public constant rewardRouter = IRewardRouter(0xB95DB5B167D75e6d04227CfFFA61069348d271F5);

    /* -------------------------------------------------------------------------- */
    /*                                 CONSTRUCTOR                                */
    /* -------------------------------------------------------------------------- */

    /**
        @notice Constructor
        @param _asset GMX
        @param _name Name of vault
        @param _symbol Symbol for Vault
    */
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        uint _harvestFee
    ) ERC4626(
        _asset,
        _name,
        _symbol
    ) Pausable(msg.sender) {
        WETH.approve(address(uniswapRouter), type(uint).max);
        _asset.approve(address(SGMX), type(uint).max);
        harvestFee = _harvestFee;
    }

    /* -------------------------------------------------------------------------- */
    /*                              PUBLIC FUNCTIONS                              */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc ERC4626
    function deposit(uint256 assets, address receiver)
        public
        override
        whenNotPaused
        returns (uint256 shares)
    {
        shares = super.deposit(assets, receiver);
        rewardRouter.stakeGmx(asset.balanceOf(address(this)));
    }

    /// @inheritdoc ERC4626
    function mint(uint256 shares, address receiver)
        public
        override
        whenNotPaused
        returns (uint256 assets)
    {
        assets = super.mint(shares, receiver);
        rewardRouter.stakeGmx(asset.balanceOf(address(this)));
    }

    /// @inheritdoc ERC4626
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this)) +
            SGMX.depositBalances(address(this), address(asset));
    }

    /// @notice Harvest rewards
    function harvest() public {
        _harvest(true);
    }

    /* -------------------------------------------------------------------------- */
    /*                             INTERNAL FUNCTIONS                             */
    /* -------------------------------------------------------------------------- */

    function _harvest(bool collectFees) internal {
        rewardRouter.compound();
        SBFGMX.claim(address(this));
        if (collectFees)
            WETH.transfer(msg.sender, WETH.balanceOf(address(this)).mulWadDown(harvestFee));
        if (WETH.balanceOf(address(this)) > 0) convertRewards();
        if (asset.balanceOf(address(this)) > 0)
            rewardRouter.stakeGmx(asset.balanceOf(address(this)));
    }

    function convertRewards() internal {
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(WETH),
                tokenOut: address(asset),
                fee: 3000,
                recipient: address(this),
                amountIn: WETH.balanceOf(address(this)),
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        uniswapRouter.exactInputSingle(params);
    }

    function beforeWithdraw(uint256 assets, uint256) internal override {
        rewardRouter.unstakeGmx(assets);
    }

    function beforeDeposit(uint256, uint256) internal override {
        _harvest(false);
    }

    function migrateAssets(address receiver) external adminOnly {
        if (receiver == address(0)) revert Errors.ZeroAddress();
        _harvest(false);
        rewardRouter.signalTransfer(receiver);
    }
}