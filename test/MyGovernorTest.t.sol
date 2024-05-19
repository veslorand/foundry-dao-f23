// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {Box} from "../src/Box.sol";
import {GovToken} from "../src/GovToken.sol";

contract MyGovernorTest is Test {
    GovToken token;
    TimeLock timelock;
    MyGovernor governor;
    Box box;

    address public USER = makeAddr("uesr");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    address[] proposers;
    address[] executors;

    uint256[] values;
    bytes[] functionCalls;
    address[] addressesToCall;

    uint256 public constant MIN_DELAY = 3600; // 1 hour - after a vote is passed, the minting will be delayed by this amount of time
    uint256 public constant VOTING_DELAY = 1; // how many blocks to wait before voting on a proposal
    uint256 public constant VOTING_PERIOD = 50400; // how many blocks to wait before voting on a proposal

    function setUp() public {
        token = new GovToken();
        token.mint(USER, 100e18);

        vm.prank(USER);
        token.delegate(USER);
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(token, timelock);
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.TIMELOCK_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, msg.sender);

        box = new Box();
        box.transferOwnership(address(timelock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 777;
        string memory description = "Store 1 in Box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        addressesToCall.push(address(box));
        values.push(0);
        functionCalls.push(encodedFunctionCall);
        // 1. Propose to the DAO
        uint256 proposalId = governor.propose(addressesToCall, values, functionCalls, description);

        // View the state of the proposal
        console.log("Proposal state: %s", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal state: %s", uint256(governor.state(proposalId)));

        // 2. Vote on the proposal
        string memory reason = "cuz blue frog is cool";
        uint8 voteWay = 1; // 1 for yes
        vm.prank(USER);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. Queue the proposal
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(addressesToCall, values, functionCalls, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 4. Execute the proposal
        governor.execute(addressesToCall, values, functionCalls, descriptionHash);

        assert(box.getNumber() == valueToStore);
        console.log(box.getNumber());
    }
}
