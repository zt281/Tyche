# Static Data Python Recovery Plan v1

## Project State at Plan Time

Pre-work completed on 2026-07-04. `AGENTS.md` was read in full. The repository has no existing `docs/design/`, `docs/plan/`, `docs/review/`, or `docs/impl/` directories, so there are no prior design-cycle plan or review logs and no impl-log CRITICAL section to carry forward. README and `docs/dynamic_module_loading_system.md` were checked for architecture context: Static Data is documented as a Python module, while C++ is reserved for hot-path gateway/engine work. Baseline `pytest tests/ -v` failed before edits with 0 collected tests, confirming the current workspace is already in a partially migrated state. Current HEAD at plan time: `[historical revision removed]`.

## Task 1: Restore Static Data Service Files

What needs to be done: restore `src/modules/static_data/` from HEAD.

Problem resolved: the module was deleted even though static metadata acquisition is a cold-path Python responsibility.

Expected result: `StaticDataConfig`, `OpenCtpDataClient`, `StaticDataStorage`, and `StaticDataModule` are importable again.

Verification: run focused static-data tests.

## Task 2: Restore Python Module Runtime Dependency

What needs to be done: restore the Python `src.tyche` module/job runtime files needed for `StaticDataModule` imports and job registration.

Problem resolved: restoring only `static_data` would still fail because `src.tyche.module`, `src.tyche.message`, `src.tyche.module_base`, and `src.tyche.types` are missing, and package initialization expects the Python runtime surface.

Expected result: `from src.modules.static_data.static_data import StaticDataModule` succeeds.

Verification: import check plus focused pytest.

## Task 3: Restore Static Data Tests and Dependencies

What needs to be done: restore `tests/test_static_data.py`, `tests/unit/test_static_data_extra.py`, and the Python dependency declaration used by the restored module.

Problem resolved: the restored Python module needs local regression coverage and clean dependency documentation.

Expected result: static-data tests are collected and pass.

Verification: `pytest tests/test_static_data.py tests/unit/test_static_data_extra.py -v`.

## Self-Review Checklist

- Scope remains limited to Static Data and its direct Python runtime dependency.
- No C++ gateway or engine behavior is changed.
- Static Data remains on the cold path.
- Tests are restored and run after implementation.
