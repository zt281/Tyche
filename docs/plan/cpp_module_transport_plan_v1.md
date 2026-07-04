# C++ Module Hybrid Transport Plan v1

## Project State at Plan Time

Pre-work completed on 2026-07-04. `AGENTS.md` was read in full, the latest existing docs were checked, and the only approved plan/impl cycle in `docs/` is for `static_data`, not C++ transport. The current implementation has `TycheModule` for ZMQ modules, `SharedMemoryBridge` for SHM-to-ZMQ forwarding, and CTP-specific `shm_writer.h` helpers. In SHM mode `CtpGateway::start()` skips `TycheModule::start()`, so it cannot use the configured ZMQ job/message path unless instruments are pre-resolved. `pytest tests/ -v` passed with 31 tests before edits. Plan context commit: `[historical revision removed]`. The required `superpowers:*` skills named by `AGENTS.md` are not installed in this session, so this plan is written manually against the same required format.

## Task 1: Add Common C++ Module Transport Helpers

What needs to be done: extend `TycheModule` with common SHM queue attachment/opening, SHM event serialization using the existing `[topic_len][topic][msgpack Message]` wire format, and a ZMQ transport startup helper with retry support.

Problem resolved: SHM event writing is currently duplicated in the CTP module, and modules launched by the SHM bridge can race engine ZMQ startup.

Expected result: any C++ module can use common code to open or attach a SHM queue and can explicitly start/retry its ZMQ side channel.

Verification: add a C++ unit test that writes a Tyche message through the common SHM helper and reads/deserializes it from `SharedMemoryQueue`.

## Task 2: Wire CTP Gateway to Hybrid Config

What needs to be done: parse optional hybrid transport fields in `GatewayConfig`, use the common SHM queue accessors, optionally start ZMQ workers in SHM mode with retries, and open the configured SHM queue in standalone mode when `use_shared_memory` is true.

Problem resolved: SHM-mode CTP cannot currently call configured ZMQ jobs such as `static_data`, and standalone config cannot activate SHM without DLL entry code injecting the queue pointer.

Expected result: CTP can run hot-path publication over SHM while still using configured ZMQ for jobs/control when enabled.

Verification: add config parsing tests for `enable_zmq_side_channel`, retry values, and SHM queue settings.

## Task 3: Update Config Examples and Run Verification

What needs to be done: update runtime/example config to show the hybrid fields, then build and run focused C++ tests plus the Python baseline.

Problem resolved: users need a concrete config shape for running SHM plus ZMQ side-channel communication.

Expected result: examples document the new behavior and tests pass.

Verification: run focused C++ test executable or CTest for new tests, plus `pytest tests/ -v`.

## Self-Review Checklist

- No SHM wire-format change.
- No hot-path JSON, filesystem, or dynamic loading work.
- ZMQ side channel is opt-in for SHM mode.
- Existing ZMQ-only startup behavior remains compatible.
- Common helper remains usable by future C++ submodules, not only CTP.
