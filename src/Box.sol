// contracts/Box.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    constructor() Ownable() {}

    uint256 private s_number;

    // Emitted when the stored value changes
    event ValueChanged(uint256 newNumber);

    // Stores a new value in the contract
    function store(uint256 newNumber) public onlyOwner {
        s_number = newNumber;
        emit ValueChanged(newNumber);
    }

    // Reads the last stored value
    function getNumber() public view returns (uint256) {
        return s_number;
    }

    // Reads the last stored value
    function retrieve() public view returns (uint256) {
        return s_number;
    }
}
