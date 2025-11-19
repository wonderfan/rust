# API Reference — Traits

This document extracts the requested trait APIs from the repository and documents:
- API name and source file
- role / purpose
- full trait definition (code block)
- explanation for each method

At the end there's a short relationships section describing ordering and dependencies between traits.

**`BlockAPI`** — `consensus/core/src/block.rs`
- **Role:** Read-only interface exposing basic block properties used across consensus code.

```rust
#[allow(private_interfaces)]
#[enum_dispatch]
pub trait BlockAPI {
    fn epoch(&self) -> Epoch;
    fn round(&self) -> Round;
    fn author(&self) -> AuthorityIndex;
    fn slot(&self) -> Slot;
    fn timestamp_ms(&self) -> BlockTimestampMs;
    fn ancestors(&self) -> &[BlockRef];
    fn transactions(&self) -> &[Transaction];
    fn transactions_data(&self) -> Vec<&[u8]>;
    fn commit_votes(&self) -> &[CommitVote];
    fn transaction_votes(&self) -> &[BlockTransactionVotes];
    fn misbehavior_reports(&self) -> &[MisbehaviorReport];
}
```

- Methods:
  - **epoch:** returns the block's epoch.
  - **round:** returns the block's round number.
  - **author:** returns authority index that produced the block.
  - **slot:** returns `Slot` (round+author) for convenience.
  - **timestamp_ms:** block timestamp in milliseconds.
  - **ancestors:** references to ancestor blocks in the DAG.
  - **transactions:** serialized transactions present in the block.
  - **transactions_data:** convenience view returning raw transaction bytes slices.
  - **commit_votes:** votes that contributed to committing the block.
  - **transaction_votes:** per-transaction votes (V2 blocks only; V1 returns empty slice).
  - **misbehavior_reports:** reports attached to the block describing misbehavior proofs.

**`CommitAPI`** — `consensus/core/src/commit.rs`
- **Role:** Accessors for persisted consensus commit metadata; a commit summarizes a CommittedSubDag.

```rust
#[enum_dispatch]
pub trait CommitAPI {
    fn round(&self) -> Round;
    fn index(&self) -> CommitIndex;
    fn previous_digest(&self) -> CommitDigest;
    fn timestamp_ms(&self) -> BlockTimestampMs;
    fn leader(&self) -> BlockRef;
    fn blocks(&self) -> &[BlockRef];
}
```

- Methods:
  - **round:** round of the commit leader (convenience -> leader.round).
  - **index:** sequential commit index.
  - **previous_digest:** digest of previous commit (for chaining).
  - **timestamp_ms:** commit timestamp (max of leader timestamp and previous commit timestamp).
  - **leader:** block reference for the leader of the commit.
  - **blocks:** ordered references to blocks included in the commit.

**`BlockStoreAPI`** (crate-private) — `consensus/core/src/linearizer.rs`
- **Role:** Abstracts a block store / DAG view used by `Linearizer` and commit reconstruction.

```rust
pub(crate) trait BlockStoreAPI {
    fn get_blocks(&self, refs: &[BlockRef]) -> Vec<Option<VerifiedBlock>>;
    fn gc_round(&self) -> Round;
    fn set_committed(&mut self, block_ref: &BlockRef) -> bool;
    fn is_committed(&self, block_ref: &BlockRef) -> bool;
}
```

- Methods:
  - **get_blocks:** batch read of `VerifiedBlock`s by `BlockRef` (missing entries return `None`).
  - **gc_round:** returns current garbage-collection round (blocks older than this may be pruned).
  - **set_committed:** mark a block as committed; returns whether the state changed.
  - **is_committed:** check if a block is already committed.

**`AuthorityAPI`** — `crates/sui-core/src/authority_client.rs`
- **Role:** Network client abstraction for interacting with a validator/authority (submit tx, query objects/effects, checkpoints, health).

```rust
#[async_trait]
pub trait AuthorityAPI {
    async fn submit_transaction(&self, request: SubmitTxRequest, client_addr: Option<SocketAddr>) -> Result<SubmitTxResponse, SuiError>;
    async fn wait_for_effects(&self, request: WaitForEffectsRequest, client_addr: Option<SocketAddr>) -> Result<WaitForEffectsResponse, SuiError>;
    async fn handle_transaction(&self, transaction: Transaction, client_addr: Option<SocketAddr>) -> Result<HandleTransactionResponse, SuiError>;
    async fn handle_certificate_v2(&self, certificate: CertifiedTransaction, client_addr: Option<SocketAddr>) -> Result<HandleCertificateResponseV2, SuiError>;
    async fn handle_certificate_v3(&self, request: HandleCertificateRequestV3, client_addr: Option<SocketAddr>) -> Result<HandleCertificateResponseV3, SuiError>;
    async fn handle_soft_bundle_certificates_v3(&self, request: HandleSoftBundleCertificatesRequestV3, client_addr: Option<SocketAddr>) -> Result<HandleSoftBundleCertificatesResponseV3, SuiError>;
    async fn handle_object_info_request(&self, request: ObjectInfoRequest) -> Result<ObjectInfoResponse, SuiError>;
    async fn handle_transaction_info_request(&self, request: TransactionInfoRequest) -> Result<TransactionInfoResponse, SuiError>;
    async fn handle_checkpoint(&self, request: CheckpointRequest) -> Result<CheckpointResponse, SuiError>;
    async fn handle_checkpoint_v2(&self, request: CheckpointRequestV2) -> Result<CheckpointResponseV2, SuiError>;
    async fn handle_system_state_object(&self, request: SystemStateRequest) -> Result<SuiSystemState, SuiError>;
    async fn validator_health(&self, request: ValidatorHealthRequest) -> Result<ValidatorHealthResponse, SuiError>;
}
```

- Methods (summary):
  - **submit_transaction:** submit a transaction for sequencing & execution.
  - **wait_for_effects:** poll/wait for transaction effects produced by the network.
  - **handle_transaction:** send a Transaction to a node API endpoint.
  - **handle_certificate_v2 / v3:** send a certified transaction for execution (different request versions).
  - **handle_soft_bundle_certificates_v3:** submit soft-bundled certificates (batch execution path).
  - **handle_object_info_request / handle_transaction_info_request:** query object/transaction details from the authority.
  - **handle_checkpoint / handle_checkpoint_v2:** request checkpoint data for syncing/checkpointing.
  - **handle_system_state_object:** fetch system state (used by benchmarks/tests).
  - **validator_health:** health/latency metrics for validator.

**`ConsensusStatsAPI`** — `crates/sui-core/src/authority/authority_per_epoch_store.rs`
- **Role:** Small metric counters for per-authority consensus statistics (enum-dispatched for versioning).

```rust
#[enum_dispatch]
pub trait ConsensusStatsAPI {
    fn is_initialized(&self) -> bool;
    fn get_num_messages(&self, authority: usize) -> u64;
    fn inc_num_messages(&mut self, authority: usize) -> u64;
    fn get_num_user_transactions(&self, authority: usize) -> u64;
    fn inc_num_user_transactions(&mut self, authority: usize) -> u64;
}
```

- Methods:
  - **is_initialized:** whether stats structure has been initialized.
  - **get_num_messages:** read messages counter for a given authority index.
  - **inc_num_messages:** increment messages counter and return new value.
  - **get_num_user_transactions:** read user transactions counter for authority.
  - **inc_num_user_transactions:** increment user transactions counter and return new value.

**`ConsensusCommitAPI`** — `crates/sui-core/src/consensus_types/consensus_output_api.rs`
- **Role:** Abstraction for consensus commit (CommittedSubDag) to Sui's execution layer; exposes leader info, timestamp, transactions and digest.

```rust
pub trait ConsensusCommitAPI: std::fmt::Display {
    fn reputation_score_sorted_desc(&self) -> Option<Vec<(AuthorityIndex, u64)>>;
    fn leader_round(&self) -> u64;
    fn leader_author_index(&self) -> AuthorityIndex;
    fn commit_timestamp_ms(&self) -> u64;
    fn commit_sub_dag_index(&self) -> u64;
    fn transactions(&self) -> Vec<(BlockRef, Vec<ParsedTransaction>)>;
    fn consensus_digest(&self, protocol_config: &ProtocolConfig) -> ConsensusCommitDigest;
}
```

- Methods:
  - **reputation_score_sorted_desc:** optional leader scoring provided by consensus (authority index + score pairs).
  - **leader_round / leader_author_index:** leader identification.
  - **commit_timestamp_ms:** timestamp of the commit.
  - **commit_sub_dag_index:** index of the committed sub-dag.
  - **transactions:** materialized list of `(BlockRef, Vec<ParsedTransaction>)` ready for execution parsing.
  - **consensus_digest:** produces a digest representing the commit (used for replay/consistency checks).

**Execution cache traits (excerpt)** — `crates/sui-core/src/execution_cache.rs`
- **Role:** Execution cache surface — separation of read, write, commit, reconfiguration and state-sync concerns used by Authority execution logic.

Key trait pieces (representative excerpts):

```rust
pub trait ExecutionCacheCommit {
    fn build_db_batch(&self) -> DBBatch;
    fn commit_transaction_outputs(&self, tx_digest: &TransactionDigest, outputs: &TransactionEffects, events: &TransactionEvents) -> SuiResult<()>;
    fn persist_transaction(&self, tx_digest: &TransactionDigest, effects: &TransactionEffects, events: &TransactionEvents) -> SuiResult<()>;
    fn approximate_pending_transaction_count(&self) -> usize;
}

pub trait ObjectCacheRead {
    fn get_package_object(&self, package: &ObjectID) -> SuiResult<Object>;
    fn get_object(&self, object_ref: &ObjectRef) -> SuiResult<Object>;
    // ...many other read helpers...
}

pub trait TransactionCacheRead {
    fn multi_get_transaction_blocks(&self, block_refs: &[BlockRef]) -> Vec<Option<CertifiedTransaction>>;
    fn multi_get_executed_effects_digests(&self, tx_digests: &[TransactionDigest]) -> Vec<Option<TransactionEffectsDigest>>;
    // ...
}

pub trait ExecutionCacheWrite {
    fn write_transaction_outputs(&self, tx_digest: TransactionDigest, outputs: TransactionEffects, events: TransactionEvents) -> SuiResult<()>;
    fn write_fastpath_transaction_outputs(&self, tx_digest: TransactionDigest, outputs: TransactionEffects, events: TransactionEvents) -> SuiResult<()>;
    fn acquire_transaction_locks(&self, tx_digest: &TransactionDigest) -> SuiResult<WriteGuard>;
}

pub trait ExecutionCacheReconfigAPI {
    fn insert_genesis_object(&self, object: Object);
    fn bulk_insert_genesis_objects(&self, objects: Vec<Object>);
    fn set_epoch_start_configuration(&self, config: EpochStartConfiguration);
    fn reconfigure_cache(&self, config: EpochStartConfiguration) -> SuiResult<()>;
}

pub trait StateSyncAPI {
    fn insert_transaction_and_effects(&self, tx: CertifiedTransaction, effects: TransactionEffects, events: TransactionEvents, committed: bool) -> SuiResult<()>;
    fn multi_insert_transaction_and_effects(&self, entries: Vec<(CertifiedTransaction, TransactionEffects, TransactionEvents, bool)>) -> SuiResult<()>;
}

pub trait TestingAPI {
    fn database_for_testing(&self) -> (&rocksdb::DB, &DBPath);
}

/// Trait alias used throughout the codebase to represent the full cache surface.
pub trait ExecutionCacheAPI: ObjectCacheRead + ExecutionCacheWrite + ExecutionCacheCommit + ExecutionCacheReconfigAPI + CheckpointCache + StateSyncAPI {}
```

- Notes on methods: these traits cover many domain-specific operations: reading/writing objects and transaction outputs, persisting and committing transactions into durable store, reconfiguration and checkpoint interactions, and state-sync insertions. See `crates/sui-core/src/execution_cache.rs` for the complete method lists and documentation.

**`TransactionEffectsAPI`** — `crates/sui-types/src/effects/mod.rs`
- **Role:** Versioned accessor API for transaction effects (enum-dispatched across versions).

```rust
#[enum_dispatch(TransactionEffectsAPI)]
pub enum TransactionEffects { /* V1, V2 ... */ }

#[enum_dispatch]
pub trait TransactionEffectsAPI {
    fn status(&self) -> &ExecutionStatus;
    fn into_status(self: Box<Self>) -> ExecutionStatus;
    fn executed_epoch(&self) -> EpochId;
    fn modified_at_versions(&self) -> Vec<(ObjectID, SequenceNumber)>;
    fn move_abort(&self) -> Option<AbortMessage>;
    fn lamport_version(&self) -> u64;
    fn old_object_metadata(&self) -> Option<Vec<ObjectInfoForEffects>>;
    fn input_consensus_objects(&self) -> Vec<ObjectRef>;
    fn created(&self) -> Vec<ObjectRef>;
    fn mutated(&self) -> Vec<ObjectRef>;
    fn unwrapped(&self) -> Vec<ObjectRef>;
    fn deleted(&self) -> Vec<ObjectRef>;
    fn unwrapped_then_deleted(&self) -> Vec<ObjectRef>;
    fn wrapped(&self) -> Vec<ObjectRef>;
    fn transferred_from_consensus(&self) -> Vec<ObjectRef>;
    fn transferred_to_consensus(&self) -> Vec<ObjectRef>;
    fn consensus_owner_changed(&self) -> Vec<ObjectRef>;
    fn object_changes(&self) -> Vec<ObjectChange>;
    fn written(&self) -> Vec<ObjectRef>;
    fn accumulator_events(&self) -> Vec<Event>;
    fn gas_object(&self) -> ObjectRef;
    fn events_digest(&self) -> Option<TransactionEventsDigest>;
    fn dependencies(&self) -> Vec<TransactionDigest>;
    fn transaction_digest(&self) -> TransactionDigest;
    fn gas_cost_summary(&self) -> GasCostSummary;
}
```

- Methods: The trait exposes accessors for every aspect of execution effects: status, epoch, object lifecycle lists (created/mutated/deleted/...), event accumulator, gas information, dependencies, and digest. Implementations are versioned (V1/V2) and bridged with `enum_dispatch`.

**`SuiGasStatusAPI`** — `crates/sui-types/src/gas.rs`
- **Role:** Accessors for Sui gas accounting state used while executing transactions.

```rust
pub trait SuiGasStatusAPI {
    fn is_unmetered(&self) -> bool;
    fn move_gas_status(&self) -> &MoveGasStatus;
    fn move_gas_status_mut(&mut self) -> &mut MoveGasStatus;
    fn bucketize_computation(&mut self, compute_gas: u64) -> Vec<ComputationCostSummary>;
    fn summary(&self) -> GasCostSummary;
    fn gas_budget(&self) -> u64;
    fn gas_price(&self) -> u64;
    fn reference_gas_price(&self) -> u64;
    fn storage_gas_units(&self) -> u64;
    fn storage_rebate(&self) -> u64;
    fn unmetered_storage_rebate(&self) -> u64;
    fn gas_used(&self) -> u64;
    fn reset_storage_cost_and_rebate(&mut self);
    fn charge_storage_read(&mut self, size: u64);
    fn charge_publish_package(&mut self, size: u64);
    fn track_storage_mutation(&mut self, prev: Option<&Object>, new: &Object);
    fn charge_storage_and_rebate(&mut self, cost: u64, rebate: u64);
    fn adjust_computation_on_out_of_gas(&mut self, used: u64);
    fn gas_usage_report(&self) -> GasUsageSummary;
}
```

- Methods: expose gas budget, gas price, storage rebate and operations to charge for storage or computation; utilities for summarizing gas usage.

**`TransactionDataAPI`** — `crates/sui-types/src/transaction.rs`
- **Role:** Read/write accessors and checks for transaction payloads (versioned via enum_dispatch).

```rust
#[enum_dispatch(TransactionDataAPI)]
pub enum TransactionData { /* V1 */ }

#[enum_dispatch]
pub trait TransactionDataAPI {
    fn sender(&self) -> SuiAddress;
    fn kind(&self) -> &TransactionKind;
    fn kind_mut(&mut self) -> &mut TransactionKind;
    fn into_kind(self: Box<Self>) -> TransactionKind;
    fn signers(&self) -> Vec<SuiAddress>;
    fn gas_data(&self) -> &GasData;
    fn gas_owner(&self) -> SuiAddress;
    fn gas(&self) -> ObjectRef;
    fn gas_price(&self) -> u64;
    fn gas_budget(&self) -> u64;
    fn expiration(&self) -> &TransactionExpiration;
    fn move_calls(&self) -> Vec<(&ModuleId, &Ident, &Vec<Value>)>;
    fn input_objects(&self) -> Vec<&InputObject>;
    fn shared_input_objects(&self) -> Vec<&SharedInputObject>;
    fn receiving_objects(&self) -> Vec<ObjectRef>;
    fn fastpath_dependency_objects(&self) -> Vec<ObjectRef>;
    fn process_funds_withdrawals(&self, /* ... */) -> SuiResult</* ... */>;
    fn has_funds_withdrawals(&self) -> bool;
    fn get_funds_withdrawals(&self) -> Vec</* ... */>;
    fn validity_check(&self, /* ... */) -> SuiResult<()>;
    fn validity_check_no_gas_check(&self, /* ... */) -> SuiResult<()>;
    fn check_sponsorship(&self, /* ... */) -> SuiResult<()>;
    fn is_system_tx(&self) -> bool;
    fn is_genesis_tx(&self) -> bool;
    fn is_end_of_epoch_tx(&self) -> bool;
    fn is_consensus_commit_prologue(&self) -> bool;
    fn is_sponsored_tx(&self) -> bool;
    fn is_gas_paid_from_address_balance(&self) -> bool;
}
```

- Methods: provide introspection for transaction sender, kind, gas details, input objects, validations, and helper checks (system/genesis/epoch/sponsorship). See full file for exact signatures and types.

**`SuiTransactionBlockEffectsAPI` & `SuiTransactionBlockDataAPI` (RPC layer)** — `crates/sui-json-rpc-types/src/sui_transaction.rs`
- **Role:** RPC-facing adapter trait views over transaction data/effects for JSON-RPC types (versioned via enum_dispatch).

```rust
pub trait SuiTransactionBlockEffectsAPI {
    fn status(&self) -> &ExecutionStatus; // and many other accessors mapping to RPC fields
    fn into_status(self: Box<Self>) -> ExecutionStatus;
    fn shared_objects(&self) -> Vec<SuiObject>;
    fn created(&self) -> Vec<SuiObject>;
    // ...and so on (mutated, unwrapped, deleted, gas_object, events_digest, dependencies ...)
}

pub trait SuiTransactionBlockDataAPI {
    fn transaction(&self) -> &SuiTransaction;
    fn sender(&self) -> &SuiAddress;
    fn gas_data(&self) -> &SuiGasData;
}
```

- Methods: these traits mirror the internal `TransactionEffectsAPI` / `TransactionDataAPI` but return RPC-serializable structures (`sui-json-rpc-types`) and are used by RPC handlers to produce responses.

---

**Relationships, ordering and dependencies (summary)**
- `BlockAPI` is the lowest-level read-only block interface used throughout consensus. `Block`/`VerifiedBlock` implement `BlockAPI`.
- `CommitAPI` represents persisted commit metadata; `CommittedSubDag` is built from `Commit` + `Block`s and is the main output delivered to execution.
- `BlockStoreAPI` abstracts reading/writing/marking blocks (the `Linearizer` uses it to construct commits). In short: Linearizer -> `BlockStoreAPI` -> `BlockAPI`/`VerifiedBlock`.
- `ConsensusCommitAPI` is the Sui-facing view for committed sub-dags (implemented for `CommittedSubDag`) and is used to convert consensus output into transactions for execution.
- `ExecutionCache*` traits form a multi-layered interface used by authorities to: read state (`ObjectCacheRead`, `TransactionCacheRead`), write execution results (`ExecutionCacheWrite`), and commit them durably (`ExecutionCacheCommit`). `ExecutionCacheReconfigAPI` and `StateSyncAPI` handle epoch reconfiguration and state-sync insertions respectively. The alias `ExecutionCacheAPI` composes these concerns and is used by high-level authority code during execution and reconfiguration.
- `TransactionEffectsAPI`, `TransactionDataAPI`, and `SuiGasStatusAPI` are versioned, enum-dispatched accessor APIs used during execution and by RPC conversion code. `TransactionEffectsAPI` is consumed by RPC mappers which implement `SuiTransactionBlockEffectsAPI`.
- `AuthorityAPI` is the network client abstraction for sending transactions and queries to validators. It is orthogonal to execution/cache traits but used by client and test code to exercise authority endpoints.
- `ConsensusStatsAPI` is a small per-author metrics interface used by `AuthorityPerEpochStore` to track consensus-related counters; it does not participate directly in commit/execution logic but records statistics used by monitoring.

Ordering / causal flow (simplified):
- Clients interact with authorities via `AuthorityAPI` (submit tx / wait for effects).
- Consensus produces certified blocks (`Block`/`VerifiedBlock`) implementing `BlockAPI`.
- `Linearizer` uses `BlockStoreAPI` to derive `Commit` objects and `CommittedSubDag`.
- `Commit` implements `CommitAPI`; `CommittedSubDag` implements/backs `ConsensusCommitAPI` to provide execution inputs.
- Execution uses `ExecutionCacheAPI` (reads from `ObjectCacheRead`, applies VM, produces `TransactionEffectsAPI` and gas accounting via `SuiGasStatusAPI`) and then persists via `ExecutionCacheCommit`.
- `TransactionEffectsAPI` is mapped into RPC-friendly `SuiTransactionBlockEffectsAPI` for JSON-RPC responses.

If you'd like, I can now:
- create a more detailed dependency graph (dot file), or
- expand any trait section with exact code comments and type links, or
- open and include any implementation examples that use a particular trait (e.g., `Linearizer::calculate_commit_timestamp`).
