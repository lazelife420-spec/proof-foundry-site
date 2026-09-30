# P5C — Publisher Source Freeze

P5C freezes the offline publisher implementation in Git before it can be considered for later publication authority.

The frozen P0–P2 site commit, tree, and manifest hash remain the trusted ancestry root. A candidate binds to the latest committed site-source change on its linear first-parent history; publisher-only descendant commits retain the previous site base. The publisher's implementation identity is recorded separately from that base. Merges, a broken first-parent chain, mismatched manifest bytes, and uncommitted non-publisher source block candidate operations. Only declared publisher source paths may be staged or untracked during source-freeze qualification. The final owner-review freeze requires every declared publisher source file to be committed and the checkout to be clean.

The source inventory for this tranche is the files listed in the final P5C/P6A report. Existing Product Module fixtures remain tracked repository fixtures. Ignored `public/` output is generated residue: it is never staged, committed, or included in candidate identity. Candidate packages and test outputs live outside the checkout or under the external candidate directory.

## Source hygiene

Source paths must not depend on the developer's absolute checkout path, an existing generated `public/` directory, a temporary candidate, a machine-local cache, or credential-bearing configuration. The protected master checkout is derived from Git worktree metadata. Qualification directs scratch site builds to isolated temporary output paths and removes those scratch builds after inspection.

## Freeze sequence

1. Inventory all untracked worktree paths and classify them.
2. Scan the exact publisher source set for machine-specific paths, credential-shaped text, unrelated product inventory, and generated output dependencies.
3. Stage only publisher implementation, tests, schemas, and tranche documentation.
4. Run the authoritative P0–P5 suite and `git diff --check` against the staged source.
5. Commit the publisher implementation on the verified linear site lineage. A later committed site correction becomes the candidate base; publisher-only commits do not advance it.
6. Re-run the qualification suite from that committed tree and verify that the commit contains no generated `public/` output.

No push, tag, release, deploy, product truth change, or artifact publication is part of P5C.
