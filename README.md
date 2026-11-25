# Multisig Treasury

An ETH treasury whose fixed owners approve transfers against a configurable threshold.

## How it works

1. Deploy with a list of distinct owners and the minimum number of approvals, then send ETH to the treasury.
2. An owner proposes a recipient and amount with `propose`. Owners call `approve(id)` separately and can revoke before execution.
3. Once the approval threshold is met, anyone can call `execute(id)` to transfer funds to the recorded recipient.

Owners and the threshold are immutable. Multiple proposals may compete for the same available balance. The treasury supports ETH transfers without arbitrary calldata.

## Build and test

Install [Foundry](https://getfoundry.sh/) and run these commands from this directory. Forge selects Solidity 0.8.36 from `foundry.toml`. The project has no third-party Solidity dependencies.

```bash
forge build
forge test -vv
forge coverage --exclude-tests
```

## Local deployment

Start a fresh `anvil` node in a separate terminal. Deploy with the first unlocked account on that local node.

```bash
export RPC_URL=http://127.0.0.1:8545
export ANVIL_ACCOUNT=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
forge create src/MultisigTreasury.sol:MultisigTreasury --rpc-url "$RPC_URL" --from "$ANVIL_ACCOUNT" --unlocked --broadcast --constructor-args "[$ANVIL_ACCOUNT,0x70997970C51812dc3A010C7d01b50e0d17dc79C8]" 2
```

## Local example

Set `CONTRACT` to the address printed by `forge create` and keep using the same terminal.

```bash
export ETH_RPC_URL="$RPC_URL"
CONTRACT=0x... # Replace with your deployed address.
SECOND_OWNER=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
cast send "$CONTRACT" --value 1ether --from "$ANVIL_ACCOUNT" --unlocked
cast send "$CONTRACT" 'propose(address,uint256)' "$SECOND_OWNER" 1000000000000000000 --from "$ANVIL_ACCOUNT" --unlocked
cast send "$CONTRACT" 'approve(uint256)' 0 --from "$ANVIL_ACCOUNT" --unlocked
cast send "$CONTRACT" 'approve(uint256)' 0 --from "$SECOND_OWNER" --unlocked
cast send "$CONTRACT" 'execute(uint256)' 0 --from "$ANVIL_ACCOUNT" --unlocked
```

## Test cases

Foundry reports 8 passing tests and 100% coverage on contract lines, statements, branches and functions.

- Invalid owner sets and unauthorized approvals, duplicate approvals and revocations.
- Two-of-three execution, request validation, repeat protection and retry after funding.
- Failed recipient calls roll back execution and preserve funds.
