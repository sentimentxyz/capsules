// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

interface IRewardRouter {
    function stakeGmx(uint256 amount) external;
    function unstakeGmx(uint256 amount) external;
    function compound() external;
}