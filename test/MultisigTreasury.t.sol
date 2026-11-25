// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {MultisigTreasury} from "../src/MultisigTreasury.sol";
import {TestBase} from "./TestBase.sol";

contract MultisigTreasuryTest is TestBase {
    MultisigTreasury private treasury;
    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    address private constant CAROL = address(0xCA01);
    address payable private constant RECIPIENT = payable(address(0xD00D));

    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = ALICE;
        owners[1] = BOB;
        owners[2] = CAROL;
        treasury = new MultisigTreasury(owners, 2);
        vm.deal(address(this), 5 ether);
    }

    function testRejectsZeroThreshold() public {
        vm.expectRevert(MultisigTreasury.InvalidThreshold.selector);
        new MultisigTreasury(new address[](0), 0);
    }

    function testRejectsThresholdAboveOwnerCount() public {
        address[] memory owners = new address[](1);
        owners[0] = ALICE;
        vm.expectRevert(MultisigTreasury.InvalidThreshold.selector);
        new MultisigTreasury(owners, 2);
    }

    function testRejectsZeroOwner() public {
        vm.expectRevert(MultisigTreasury.InvalidOwner.selector);
        new MultisigTreasury(new address[](1), 1);
    }

    function testRejectsDuplicateOwner() public {
        address[] memory owners = new address[](2);
        owners[0] = ALICE;
        owners[1] = ALICE;
        vm.expectRevert(MultisigTreasury.InvalidOwner.selector);
        new MultisigTreasury(owners, 1);
    }

    function testOwnersAndProposalAreValidated() public {
        vm.expectRevert(MultisigTreasury.Unauthorized.selector);
        treasury.propose(RECIPIENT, 1);
        vm.prank(ALICE);
        vm.expectRevert(MultisigTreasury.InvalidPayment.selector);
        treasury.propose(payable(address(0)), 1);
        vm.prank(ALICE);
        vm.expectRevert(MultisigTreasury.InvalidPayment.selector);
        treasury.propose(RECIPIENT, 0);
        vm.expectRevert(MultisigTreasury.UnknownProposal.selector);
        treasury.execute(0);

        uint256 id = propose(RECIPIENT);
        vm.expectRevert(MultisigTreasury.Unauthorized.selector);
        treasury.approve(id);
        vm.expectRevert(MultisigTreasury.Unauthorized.selector);
        treasury.revoke(id);
    }

    function testThresholdWithRevocationAndReplacementApproval() public {
        fund();
        uint256 id = propose(RECIPIENT);
        vm.prank(ALICE);
        vm.expectRevert(MultisigTreasury.MissingApproval.selector);
        treasury.revoke(id);
        approve(ALICE, id);
        vm.prank(ALICE);
        vm.expectRevert(MultisigTreasury.AlreadyApproved.selector);
        treasury.approve(id);
        approve(BOB, id);
        vm.prank(BOB);
        treasury.revoke(id);

        vm.expectRevert(MultisigTreasury.InsufficientApprovals.selector);
        treasury.execute(id);
        assertTrue(!treasury.approved(id, BOB));

        approve(CAROL, id);
        treasury.execute(id);
        assertEq(RECIPIENT.balance, 1 ether);
        assertEq(address(treasury).balance, 0);
        vm.expectRevert(MultisigTreasury.AlreadyExecuted.selector);
        treasury.execute(id);
    }

    function testInsufficientFundingAllowsRetry() public {
        uint256 id = propose(RECIPIENT);
        approve(ALICE, id);
        approve(BOB, id);
        vm.expectRevert(MultisigTreasury.TransferFailed.selector);
        treasury.execute(id);
        fund();
        treasury.execute(id);
        assertEq(RECIPIENT.balance, 1 ether);
    }

    function testRecipientFailurePreservesFundsAndApprovals() public {
        fund();
        uint256 id = propose(payable(address(this)));
        approve(ALICE, id);
        approve(BOB, id);
        vm.expectRevert(MultisigTreasury.TransferFailed.selector);
        treasury.execute(id);

        (,, uint256 approvals, bool executed) = treasury.payments(id);
        assertEq(approvals, 2);
        assertTrue(!executed);
        assertEq(address(treasury).balance, 1 ether);
    }

    function propose(address payable recipient) private returns (uint256) {
        vm.prank(ALICE);
        return treasury.propose(recipient, 1 ether);
    }

    function approve(address owner, uint256 id) private {
        vm.prank(owner);
        treasury.approve(id);
    }

    function fund() private {
        (bool sent,) = address(treasury).call{value: 1 ether}("");
        assertTrue(sent);
    }
}
