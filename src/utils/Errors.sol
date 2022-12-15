// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library Errors {
    error AdminOnly();
    error MaxSupply();
    error ZeroShares();
    error ZeroAssets();
    error ZeroAddress();
    error MinimumShares();
    error TokenNotContract();
    error AddressNotContract();
    error ContractNotPaused();
    error ContractPaused();
}