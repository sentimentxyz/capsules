// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Errors} from "./Errors.sol";
import {Ownable} from  "./Ownable.sol";

abstract contract Pausable is Ownable {
    bool public paused;

    event PauseToggled(address indexed admin, bool pause);

    constructor(address _admin) Ownable(_admin) {}

    modifier whenNotPaused() {
        if (paused) revert Errors.ContractPaused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert  Errors.ContractNotPaused();
        _;
    }

    function togglePause() external adminOnly {
        paused = !paused;
        emit PauseToggled(msg.sender, paused);
    }
}