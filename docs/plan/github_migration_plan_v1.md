# GitHub Multi-Repository Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish the four prepared component repositories and the Tyche aggregation repository as public GitHub repositories with working submodule references, while adding the original-repository deprecation notice safely.

**Architecture:** Use the prepared local repository histories as the source of truth. Publish component repositories first, register them as submodules in the aggregation repository, then publish the aggregation repository and verify each remote and checkout path.

**Tech Stack:** Git, GitHub CLI (`gh`), GitHub Actions, CMake/CTest, Python/pytest/ruff, PowerShell.

## Global Constraints

- All five new repositories are public under `zt281`.
- Push component repositories before the aggregation repository.
- Do not force-push or rewrite any remote history.
- Do not stage or alter the unrelated existing changes in `D:/dev/TycheEngine`.
- Do not delete `TycheEngine-backup.git` or any `*-work` directory.
- PyPI publication, original-repository archiving, team notification, and workspace cleanup remain deferred.

---

## Project State at Plan Time

The approved design is `docs/design/github_migration_design_v1.md`. The component copies are clean on `main` at `[historical revision removed]`, `4f15bcc`, `3c1c07a`, and `58f5d1f`; they have no `origin` remotes. `Tyche-work` is clean at `[historical revision removed]`, has four `.gitkeep` placeholders, and currently points `origin` at the local backup. `D:/dev/TycheEngine` is dirty with pre-existing work, so its deprecation change must use an explicit pathspec.

### Task 1: Record and review the migration plan

**Files:**
- Create: `docs/design/github_migration_design_v1.md`
- Create: `docs/plan/github_migration_plan_v1.md`
- Create: `docs/review/github_migration_plan_v1_review_round1.log`
- Create: `docs/impl/github_migration_implement_v1.md`

**Interfaces:**
- Consumes: `NEXT_STEPS.md`, local repository state, and the approved public-visibility decision.
- Produces: an approved plan and an implementation log used to record command output for later tasks.

- [ ] **Step 1: Review the plan against the local state and the approved design.**

  Check that the plan preserves the original repository's dirty files, uses no force-push, publishes components before the aggregation repository, and defers destructive optional actions.

- [ ] **Step 2: Record the review verdict.**

  The review log must end with:

  ```text
  Result: APPROVED
  ```

- [ ] **Step 3: Commit the design, plan, review log, and implementation log.**

  ```powershell
  git -C D:\dev\tyche-split\Tyche-work add docs/design/github_migration_design_v1.md docs/plan/github_migration_plan_v1.md docs/review/github_migration_plan_v1_review_round1.log docs/impl/github_migration_implement_v1.md
  git -C D:\dev\tyche-split\Tyche-work commit -m "docs: record GitHub migration plan (TASK-0 GREEN)"
  ```

  Expected result: one commit contains only the four migration documents.

### Task 2: Create public repositories and configure local remotes

**Files:**
- Modify: Git remote configuration for the five prepared repositories.

**Interfaces:**
- Consumes: authenticated `gh` session for account `zt281`.
- Produces: five public repositories and matching `origin` URLs.

- [ ] **Step 1: Verify repository targets before creation.**

  ```powershell
  gh auth status
  foreach ($repo in @('TycheCore-CPP','TycheEngine-Python','ctp-gateway-cpp','static-data','Tyche')) {
      gh repo view "zt281/$repo" --json name,isPrivate,defaultBranchRef,url
  }
  ```

  Expected result: the account is authenticated; a missing repository is reported as not found and an existing repository is inspected before reuse.

- [ ] **Step 2: Create only missing repositories as public, empty repositories.**

  ```powershell
  foreach ($repo in @('TycheCore-CPP','TycheEngine-Python','ctp-gateway-cpp','static-data','Tyche')) {
      gh repo view "zt281/$repo" --json name *> $null
      if ($LASTEXITCODE -ne 0) {
          gh repo create "zt281/$repo" --public --description "Tyche multi-repository component" --disable-issues --disable-wiki
      }
  }
  ```

  Expected result: all five repositories exist and are public. If an existing repository is non-empty or has an incompatible default branch, stop before pushing it.

- [ ] **Step 3: Set or add each local `origin` without changing commits.**

  ```powershell
  $mapping = @(
      @{ Path='TycheCore-CPP-work'; Repo='TycheCore-CPP' },
      @{ Path='TycheEngine-Python-work'; Repo='TycheEngine-Python' },
      @{ Path='ctp-gateway-cpp-work'; Repo='ctp-gateway-cpp' },
      @{ Path='static-data-work'; Repo='static-data' },
      @{ Path='Tyche-work'; Repo='Tyche' }
  )
  foreach ($item in $mapping) {
      $path = Join-Path 'D:\dev\tyche-split' $item.Path
      $url = "https://github.com/zt281/$($item.Repo).git"
      git -C $path remote get-url origin *> $null
      if ($LASTEXITCODE -eq 0) { git -C $path remote set-url origin $url }
      else { git -C $path remote add origin $url }
      git -C $path remote get-url origin
  }
  ```

  Expected result: each `origin` is the matching GitHub URL.

### Task 3: Push the four component repositories

**Files:**
- Modify: remote state of `TycheCore-CPP`, `TycheEngine-Python`, `ctp-gateway-cpp`, and `static-data`.

**Interfaces:**
- Consumes: the four configured public remotes from Task 2.
- Produces: pushed `main` branches whose heads match the prepared local commits.

- [ ] **Step 1: Verify each component is clean and has the expected head.**

  ```powershell
  git -C D:\dev\tyche-split\TycheCore-CPP-work status --porcelain=v1
  git -C D:\dev\tyche-split\TycheEngine-Python-work status --porcelain=v1
  git -C D:\dev\tyche-split\ctp-gateway-cpp-work status --porcelain=v1
  git -C D:\dev\tyche-split\static-data-work status --porcelain=v1
  ```

  Expected result: no output from all four commands.

- [ ] **Step 2: Push `main` in dependency order.**

  ```powershell
  foreach ($path in @('TycheCore-CPP-work','TycheEngine-Python-work','ctp-gateway-cpp-work','static-data-work')) {
      git -C (Join-Path 'D:\dev\tyche-split' $path) push -u origin main
  }
  ```

  Expected result: each command exits 0 without force-push; record the resulting remote head SHA in the implementation log.

- [ ] **Step 3: Verify remote heads.**

  ```powershell
  foreach ($repo in @('TycheCore-CPP','TycheEngine-Python','ctp-gateway-cpp','static-data')) {
      gh api "repos/zt281/$repo/commits/main" --jq '.sha'
  }
  ```

  Expected result: the four SHAs equal the local prepared heads.

### Task 4: Register the four aggregation submodules

**Files:**
- Modify: `D:/dev/tyche-split/Tyche-work/.gitmodules`
- Delete: `D:/dev/tyche-split/Tyche-work/core/cpp/.gitkeep`
- Delete: `D:/dev/tyche-split/Tyche-work/core/python/.gitkeep`
- Delete: `D:/dev/tyche-split/Tyche-work/modules/ctp-gateway-cpp/.gitkeep`
- Delete: `D:/dev/tyche-split/Tyche-work/modules/static-data/.gitkeep`

**Interfaces:**
- Consumes: public component repositories and the existing `.gitmodules` URL mappings.
- Produces: four gitlink entries pointing at the pushed component heads.

- [ ] **Step 1: Confirm the placeholder-only precondition.**

  ```powershell
  $aggregate = 'D:\dev\tyche-split\Tyche-work'
  foreach ($relative in @('core/cpp','core/python','modules/ctp-gateway-cpp','modules/static-data')) {
      Get-ChildItem -LiteralPath (Join-Path $aggregate $relative) -Force | Select-Object -ExpandProperty Name
  }
  ```

  Expected result: each directory contains only `.gitkeep`.

- [ ] **Step 2: Remove only the four placeholders and add the public submodules.**

  ```powershell
  git -C D:\dev\tyche-split\Tyche-work rm -- core/cpp/.gitkeep core/python/.gitkeep modules/ctp-gateway-cpp/.gitkeep modules/static-data/.gitkeep
  git -C D:\dev\tyche-split\Tyche-work submodule add --force https://github.com/zt281/TycheCore-CPP.git core/cpp
  git -C D:\dev\tyche-split\Tyche-work submodule add --force https://github.com/zt281/TycheEngine-Python.git core/python
  git -C D:\dev\tyche-split\Tyche-work submodule add --force https://github.com/zt281/ctp-gateway-cpp.git modules/ctp-gateway-cpp
  git -C D:\dev\tyche-split\Tyche-work submodule add --force https://github.com/zt281/static-data.git modules/static-data
  ```

  Expected result: all four paths are populated from GitHub, `.gitmodules` remains consistent, and the index records gitlinks rather than regular files.

- [ ] **Step 3: Verify the submodule index before committing.**

  ```powershell
  git -C D:\dev\tyche-split\Tyche-work submodule status
  git -C D:\dev\tyche-split\Tyche-work diff --cached --submodule=short
  ```

  Expected result: four submodule entries point at the four pushed component heads; no unrelated files are staged.

- [ ] **Step 4: Commit the submodule registration.**

  ```powershell
  git -C D:\dev\tyche-split\Tyche-work add .gitmodules
  git -C D:\dev\tyche-split\Tyche-work commit -m "feat: register public component submodules (TASK-4 GREEN)"
  ```

  Expected result: one aggregation commit contains the four gitlinks and any required `.gitmodules` update only.

### Task 5: Push the aggregation repository

**Files:**
- Modify: remote state of `D:/dev/tyche-split/Tyche-work`.

**Interfaces:**
- Consumes: the submodule commit from Task 4 and the four public component repositories.
- Produces: public `zt281/Tyche` `main` branch with checkoutable submodules.

- [ ] **Step 1: Push `main` without force.**

  ```powershell
  git -C D:\dev\tyche-split\Tyche-work push -u origin main
  ```

  Expected result: exit 0 and the aggregation branch is created or fast-forwarded.

- [ ] **Step 2: Verify the public aggregation repository and submodule URLs.**

  ```powershell
  gh repo view zt281/Tyche --json name,isPrivate,defaultBranchRef,url
  git -C D:\dev\tyche-split\Tyche-work ls-tree HEAD core/cpp core/python modules/ctp-gateway-cpp modules/static-data
  ```

  Expected result: `isPrivate` is `false`; all four paths have mode `160000` gitlinks.

### Task 6: Add and push the original-repository deprecation notice

**Files:**
- Create: `D:/dev/TycheEngine/DEPRECATED.md`

**Interfaces:**
- Consumes: `D:/dev/tyche-split/DEPRECATION_NOTICE.md`.
- Produces: a single-file deprecation commit on the original repository's `main` branch.

- [ ] **Step 1: Confirm the original repository's existing dirty set.**

  ```powershell
  git -C D:\dev\TycheEngine status --short
  ```

  Expected result: the pre-existing files are recorded before the new file is added.

- [ ] **Step 2: Create `DEPRECATED.md` with the prepared notice and stage only that path.**

  ```powershell
  git -C D:\dev\TycheEngine add -- DEPRECATED.md
  git -C D:\dev\TycheEngine diff --cached --name-only
  ```

  Expected result: the staged-name output is exactly `DEPRECATED.md`.

- [ ] **Step 3: Commit and push only the deprecation notice.**

  ```powershell
  git -C D:\dev\TycheEngine commit -m "chore: add deprecation notice for multi-repo migration (TASK-6 GREEN)"
  git -C D:\dev\TycheEngine push origin main
  ```

  Expected result: the new commit is pushed; the original dirty files remain unstaged and untouched.

### Task 7: Run local and remote verification

**Files:**
- Modify: `docs/impl/github_migration_implement_v1.md` with command evidence.

**Interfaces:**
- Consumes: all pushed repository heads and local toolchains.
- Produces: a completed migration checklist with explicit pass/fail/blocked evidence.

- [ ] **Step 1: Run repository metadata and submodule verification.**

  ```powershell
  gh repo list zt281 --limit 20 --json name,isPrivate,defaultBranchRef,url
  git -C D:\dev\tyche-split\Tyche-work submodule sync --recursive
  git -C D:\dev\tyche-split\Tyche-work submodule status --recursive
  git -C D:\dev\tyche-split\Tyche-work status --short --branch
  ```

- [ ] **Step 2: Run the available component checks.**

  ```powershell
  cmake -B D:\dev\tyche-split\TycheCore-CPP-work\build -S D:\dev\tyche-split\TycheCore-CPP-work -DCMAKE_BUILD_TYPE=Release
  cmake --build D:\dev\tyche-split\TycheCore-CPP-work\build --config Release
  ctest --test-dir D:\dev\tyche-split\TycheCore-CPP-work\build --output-on-failure
  python -m pytest D:\dev\tyche-split\TycheEngine-Python-work\tests -q
  python -m ruff check D:\dev\tyche-split\TycheEngine-Python-work
  python -m pytest D:\dev\tyche-split\static-data-work\tests -q
  python -m ruff check D:\dev\tyche-split\static-data-work
  cmake -B D:\dev\tyche-split\ctp-gateway-cpp-work\build -S D:\dev\tyche-split\ctp-gateway-cpp-work -DCMAKE_BUILD_TYPE=Release -DCTP_USE_SUBMODULE=ON
  cmake --build D:\dev\tyche-split\ctp-gateway-cpp-work\build --config Release
  ```

  Record toolchain-missing conditions separately from test failures; do not claim a skipped command passed.

- [ ] **Step 3: Inspect GitHub Actions after push.**

  ```powershell
  foreach ($repo in @('TycheCore-CPP','TycheEngine-Python','ctp-gateway-cpp','static-data','Tyche')) {
      gh run list --repo "zt281/$repo" --limit 5 --json databaseId,status,conclusion,workflowName,headBranch,url
  }
  ```

  Expected result: report each workflow as passed, running, failed, or unavailable; failed workflows require their logs to be investigated before the migration can be called complete.

### Task 8: Explicitly defer optional/destructive follow-up

**Files:**
- Modify: `docs/impl/github_migration_implement_v1.md` with the final disposition.

- [ ] **Step 1: Verify that no PyPI upload, repository archive, team message, or work-copy deletion was performed.**

- [ ] **Step 2: Report these as deferred follow-ups, together with the retained backup path `D:/dev/tyche-split/TycheEngine-backup.git`.**

## Plan Self-Review

- The design decision that all five repositories are public is covered by Tasks 2, 3, and 5.
- The push dependency order is covered by Tasks 3 through 5.
- Placeholder replacement and four submodule registrations are covered by Task 4.
- The original dirty working tree safety requirement is covered by Task 6.
- CI/local validation is covered by Task 7.
- Optional and destructive actions are explicitly deferred by Task 8.
- No force-push, recursive deletion, or broad staging command is present.
