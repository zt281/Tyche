# Static Data Python Recovery Design v1

## Project State at Design Time

The working tree is in the middle of a C++ migration: the C++ CTP gateway remains present and already expects a `static_data` job service, while `src/modules/static_data/` and the Python `src.tyche` module runtime were deleted from the workspace. There are no existing `docs/design/`, `docs/plan/`, `docs/review/`, or `docs/impl/` documents to inherit from. README still describes Static Data as a Python exchange metadata caching service, and the C++ gateway treats it as a cold-path dependency for resolving instruments.

## Intent

Restore Static Data as a lightweight Python module because exchange metadata lookup, OpenCTP DataCenter REST calls, JSON persistence, and query filtering are cold-path operations. These operations do not justify a C++ module implementation and should stay outside the low-latency market-data hot path.

## Scope

Restore:

- `src/modules/static_data/` as the Python static metadata service.
- The minimal Python `src.tyche` module/job runtime required by `StaticDataModule`.
- Static Data focused tests.
- Python dependency declaration needed by the restored module.

Do not change:

- C++ CTP gateway behavior.
- C++ engine/shared-memory code.
- Existing CMake files.
- Other deleted domain modules such as Greeks Engine.

## Runtime Boundary

`static_data` runs as a Python Tyche module with family name `static_data`. It registers `handle_query_*` job handlers with the engine and serves cached metadata from local JSON files after refreshing from OpenCTP DataCenter. The C++ gateway remains a consumer through job requests and does not embed static-data fetch logic.

## Verification

Use focused pytest coverage for:

- Static data storage save/load/metadata behavior.
- OpenCTP client URL construction, API error handling, and retry failure.
- Query filtering and handler responses.
- Refresh behavior and lifecycle helper methods.
