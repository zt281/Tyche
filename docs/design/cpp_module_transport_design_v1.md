# C++ Module Hybrid Transport Design v1

## Project State at Design Time

Pre-work completed on 2026-07-04. `AGENTS.md` was read in full and has no concrete `Current State` section beyond the process rule reference. The latest existing design cycle is `static_data_design_v1`, which is unrelated and explicitly excludes C++ gateway or engine behavior. `docs/dynamic_module_loading_system.md` is approved and documents the current SHM-to-ZMQ bridge: DLL/SO modules write `[topic_len][topic][payload]` into `SharedMemoryQueue`, and `SharedMemoryBridge` forwards the payload into the engine topic queues. Baseline `pytest tests/ -v` passed with 31 tests before edits. Current HEAD at design time: `[historical revision removed]`.

## Intent

Allow C++ submodules running in shared-memory mode to keep a configurable ZMQ side channel for registration, jobs, and lower-frequency module communication, while retaining shared memory for hot-path event publication to other modules through the engine bridge.

## Scope

Change the common C++ module layer so shared-memory publication is not a CTP-only helper and ZMQ startup can be retried when a SHM module is launched before the engine workers are listening.

Change the CTP gateway only as the first consumer of the common transport helpers:

- `use_shared_memory` continues to route hot-path quote events through SHM.
- A config flag enables the ZMQ side channel in SHM mode for job requests such as `query_instruments`.
- Standalone CTP gateway mode can open the configured SHM queue from the config file, matching the DLL mode behavior.

## Runtime Boundary

Config parsing and queue opening remain cold-path startup work. The hot path keeps the existing SHM wire format and the engine bridge keeps forwarding raw payload bytes with no new parsing beyond the existing topic header.

## Configuration Shape

The CTP gateway config gains optional gateway fields:

- `enable_zmq_side_channel`: when true in SHM mode, start the normal TycheModule ZMQ workers as a side channel.
- `zmq_connect_retries`: registration retry count for the side channel.
- `zmq_connect_retry_interval_ms`: delay between side-channel registration attempts.

The existing fields `use_shared_memory`, `shm_queue_name`, and `shm_tuning` continue to define the SHM queue and size parameters.

## Invariants

- Do not change the SHM message format.
- Do not perform JSON parsing, filesystem access, or queue creation inside tick/dispatch hot paths.
- Do not remove the current ZMQ-only module path.
- A failed optional ZMQ side channel must not prevent SHM hot-path startup.

## Verification

Use C++ tests for:

- Common `TycheModule` SHM event serialization into `SharedMemoryQueue`.
- Common `TycheModule` opening a configured SHM queue.
- Gateway config parsing of SHM/ZMQ hybrid fields.

Then run focused C++ build/tests and the existing Python baseline.
