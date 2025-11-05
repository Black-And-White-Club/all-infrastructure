# Migration guidance

This document contains suggested approaches for moving shared pieces from the project repositories into this shared `all-infrastructure` repository.

Quick copy (fast, no history)

1. Copy directories from `frolf-bot-infrastructure` and `resume-infrastructure` into `all-infrastructure` in the desired locations.
2. Commit and push.
3. Remove copied files from the project repos and add a README pointing at `all-infrastructure`.

Preserve history (recommended if you care about auditability)

- Using `git subtree` (simple):

  1. Add the source repo as a remote:

     git remote add frolf /path/to/frolf-bot-infrastructure
     git fetch frolf

  2. Create a subtree split of the folder you want to import and push it to this repo:

     git subtree split -P terraform/modules/cloud-engine -b cloud-engine-history
     git remote add allinfra /path/to/all-infrastructure
     git push allinfra cloud-engine-history:refs/heads/import-cloud-engine

- Using `git filter-repo` (more flexible and faster for larger history):
  See the `git-filter-repo` documentation — extract paths into a new branch and push them into this repo.

Notes

- When preserving history, you may need to rewrite paths (prefix) so the code lands under the correct `terraform/modules/...` path in `all-infrastructure`.
- Test the import on a fork or clone before modifying main branches.
