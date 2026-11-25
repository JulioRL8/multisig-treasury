// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

contract MultisigTreasury {
    error InvalidThreshold();
    error InvalidOwner();
    error Unauthorized();
    error InvalidPayment();
    error UnknownProposal();
    error AlreadyExecuted();
    error AlreadyApproved();
    error MissingApproval();
    error InsufficientApprovals();
    error TransferFailed();

    struct Payment {
        address payable recipient;
        uint256 amount;
        uint256 approvals;
        bool executed;
    }

    mapping(address owner => bool) public isOwner;
    mapping(uint256 id => mapping(address owner => bool)) public approved;
    uint256 public immutable threshold;
    Payment[] public payments;

    event Deposited(address indexed payer, uint256 amount);
    event Proposed(uint256 indexed id, address indexed recipient, uint256 amount);
    event ApprovalChanged(uint256 indexed id, address indexed owner, bool approved);
    event Executed(uint256 indexed id);

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert Unauthorized();
        _;
    }

    constructor(address[] memory owners, uint256 required) {
        if (required == 0) revert InvalidThreshold();
        if (required > owners.length) revert InvalidThreshold();
        for (uint256 i; i < owners.length; ++i) {
            address owner = owners[i];
            if (owner == address(0)) revert InvalidOwner();
            if (isOwner[owner]) revert InvalidOwner();
            isOwner[owner] = true;
        }
        threshold = required;
    }

    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    function propose(address payable recipient, uint256 amount) external onlyOwner returns (uint256 id) {
        if (recipient == address(0)) revert InvalidPayment();
        if (amount == 0) revert InvalidPayment();

        id = payments.length;
        payments.push(Payment(recipient, amount, 0, false));
        emit Proposed(id, recipient, amount);
    }

    function approve(uint256 id) external onlyOwner {
        Payment storage payment = _pending(id);
        if (approved[id][msg.sender]) revert AlreadyApproved();
        approved[id][msg.sender] = true;
        ++payment.approvals;
        emit ApprovalChanged(id, msg.sender, true);
    }

    function revoke(uint256 id) external onlyOwner {
        Payment storage payment = _pending(id);
        if (!approved[id][msg.sender]) revert MissingApproval();
        approved[id][msg.sender] = false;
        --payment.approvals;
        emit ApprovalChanged(id, msg.sender, false);
    }

    function execute(uint256 id) external {
        Payment storage payment = _pending(id);
        if (payment.approvals < threshold) revert InsufficientApprovals();

        payment.executed = true;
        emit Executed(id);
        (bool sent,) = payment.recipient.call{value: payment.amount}("");
        if (!sent) revert TransferFailed();
    }

    function _pending(uint256 id) private view returns (Payment storage payment) {
        if (id >= payments.length) revert UnknownProposal();
        payment = payments[id];
        if (payment.executed) revert AlreadyExecuted();
    }
}
