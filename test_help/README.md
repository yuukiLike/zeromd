# md sync Manual Test

This checklist is for local manual verification of daily `md` / `gmd sync`.

## Goal

Verify that a markdown change in the vault can be detected, committed, and pushed by zeromd.

## Preconditions

- you are in the zeromd repo root
- `origin` is reachable
- use `gmd` by default
- if your shell does not occupy `md`, you can use `md` instead

## Steps

1. Initialize zeromd on this Mac:

```bash
bash scripts/setup.sh
```

During setup, choose either `SSH` or `HTTPS` for the GitHub remote.

2. Open your Obsidian vault directory.
3. Create or edit a markdown file, for example:

```bash
echo "$(date '+%Y-%m-%d %H:%M:%S') manual sync test" >> test-sync.md
```

4. Check current sync status:

```bash
gmd status
```

5. Trigger a foreground sync:

```bash
gmd sync
```

6. Check status again:

```bash
gmd status
```

7. Inspect local git state:

```bash
git status --short
git log --oneline -3
```

8. Confirm the new auto-sync commit also appears on the remote repository.

## Expected Result

- `gmd sync` exits successfully
- `gmd status` shows a recent successful sync
- local `git status --short` is clean
- local history contains a new `auto-sync: ...` commit
- the same commit is visible on the remote repository

## Notes

- If `gmd sync` fails, run `gmd doctor`
- If you chose `HTTPS`, Git may prompt for credentials during setup or sync
- If you want detailed execution logs, run `gmd log 50`
