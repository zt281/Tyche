# GitHub Multi-Repository Migration Design v1

## Project State at Design Time

The migration work copies are already prepared under `D:/dev/tyche-split/`.
The four component repositories are clean `main` branches without an `origin` remote. The aggregation repository is a clean `main` branch whose current `origin` still points to the local `TycheEngine-backup.git`. Its four new component directories contain `.gitkeep` placeholders, while `.gitmodules` already contains the intended public GitHub URL mappings. The original `D:/dev/TycheEngine` checkout has unrelated uncommitted changes.

## Approved Decisions

- The five new GitHub repositories are public and owned by `zt281`.
- The four component repositories are pushed before the aggregation repository.
- The aggregation repository registers the four components as real Git submodules, then pushes the resulting commit to GitHub.
- The original checkout receives only a new `DEPRECATED.md` file. Existing uncommitted changes are not staged or rewritten.
- PyPI publication, original-repository archiving, team notification, and deletion of temporary copies are deferred because they are optional, irreversible, require external target information, or would destroy the local rollback copies.

## Execution Architecture

The migration is an ordered remote-publication flow:

1. Create or verify five empty public repositories.
2. Point each prepared copy at its matching GitHub repository and push `main`.
3. Replace the aggregation placeholders with submodule gitlinks using the already-approved `.gitmodules` URLs.
4. Push the aggregation repository after all referenced component commits are available.
5. Verify repository metadata, submodule checkoutability, local build/test commands, and GitHub Actions results where available.

## Safety and Failure Handling

- Every repository is checked for existing contents and remote state before mutation.
- Existing repositories are reused only if their default branch and existing history are compatible with the prepared copy; no force-push is used.
- The aggregation placeholders are removed only after confirming they are the four expected `.gitkeep` files.
- The original repository is staged with an explicit pathspec for `DEPRECATED.md` only.
- Temporary work copies and `TycheEngine-backup.git` remain available for rollback.

## Verification

The final checklist must show five public repositories, five pushed `main` branches, four registered submodules, clean local repository states except for the original pre-existing changes, successful focused/local CI-equivalent checks where the host has the required toolchains, and the original deprecation commit pushed without unrelated files.
