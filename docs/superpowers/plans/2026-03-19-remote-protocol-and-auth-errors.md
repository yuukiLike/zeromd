# Remote Protocol And Auth Errors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users choose `SSH` or `HTTPS` during setup, warn clearly when an existing `origin` uses a different protocol, and surface actionable sync auth errors instead of generic git failures.

**Architecture:** Keep the change inside the existing bash scripts. `setup.sh` owns protocol selection and existing-origin messaging; `sync.sh` owns git stderr capture and error classification. Tests stay in the existing bash test harness.

**Tech Stack:** Bash, git, zeromd's existing shell test runner

---

### Task 1: Protocol Selection In Setup

**Files:**
- Modify: `scripts/setup.sh`
- Test: `tests/test_setup.sh`

- [ ] Step 1: Write failing tests for SSH/HTTPS URL handling and protocol mismatch messaging
- [ ] Step 2: Run `bash tests/run.sh` and verify the new setup tests fail for the missing behavior
- [ ] Step 3: Add minimal protocol helpers and setup flow updates in `scripts/setup.sh`
- [ ] Step 4: Re-run `bash tests/run.sh` and verify the setup tests pass

### Task 2: Auth Error Classification In Sync

**Files:**
- Modify: `scripts/sync.sh`
- Test: `tests/test_sync.sh`

- [ ] Step 1: Write failing tests for HTTPS auth failure, SSH auth failure, and generic push/fetch error classification
- [ ] Step 2: Run `bash tests/run.sh` and verify the new sync tests fail for the missing behavior
- [ ] Step 3: Add stderr capture and classification helpers in `scripts/sync.sh`
- [ ] Step 4: Re-run `bash tests/run.sh` and verify the sync tests pass

### Task 3: User-Facing Copy

**Files:**
- Modify: `scripts/zeromd`
- Modify: `README.md`
- Modify: `README.zh.md`
- Modify: `test_help/README.md`

- [ ] Step 1: Update docs/help text to mention SSH/HTTPS support and clearer auth error expectations
- [ ] Step 2: Run `bash tests/run.sh` and verify no regressions
