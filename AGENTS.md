# AGENTS.md

## Required context

Read [`README.md`](README.md) before changing this repository. Its **Project
context** section records the repository model, upstream pin, current release,
release naming, and validation status.

Use these references when relevant:

- [`docs/amtm/README.md`](docs/amtm/README.md) describes installation and operation.
- [`docs/amtm/FINDINGS.md`](docs/amtm/FINDINGS.md) records verified behavior and open hardware work.
- [`docs/amtm/UPSTREAM.md`](docs/amtm/UPSTREAM.md) defines the upstream update process.
- [`upstream/AGENTS.md`](upstream/AGENTS.md) applies when inspecting Grafana Alloy source.

## Repository boundaries

- Treat this repository as a thin downstream distribution of Grafana Alloy.
- Keep AMTM-owned code in `packaging/amtm/`, tests in `tests/amtm/`, and AMTM
  documentation in `docs/amtm/`.
- Treat `upstream/` as an unmodified Git submodule. Don't commit files inside
  it or copy upstream source into the primary repository.
- When updating Alloy, change the `upstream` gitlink and
  `packaging/amtm/UPSTREAM_VERSION` together. Their commit hashes must match.
- Initialize the source checkout with `git submodule update --init --recursive`.
- Keep each change focused on one logical purpose.

## Git identity

Use this repository-local author identity for commits:

```text
YongaQ <311870715+yongaqcom@users.noreply.github.com>
```

Don't use a cached Git identity from another GitHub account.

## Validation

For packaging or workflow changes, run the following checks when the required
tools are available:

```sh
shellcheck -s sh packaging/amtm/*.sh packaging/amtm/alloy-amtm \
  packaging/amtm/S99alloy tests/amtm/shell_test.sh
sh tests/amtm/shell_test.sh
```

The release workflow must also pass the static `linux/arm64` build, ELF static
linkage check, QEMU startup and configuration validation, archive creation, and
checksum verification. Automated checks don't replace physical RT-BE88U boot,
upgrade, rollback, resource, and soak testing.

## Releases

- Use `vX.Y.Z-amtm.N`, where `X.Y.Z` matches the upstream Alloy version and
  `N` is the downstream packaging revision.
- A branch push creates only a temporary Actions artifact. A pushed
  `v*-amtm.*` tag creates the GitHub Release.
- Never move or reuse a published tag.
- Don't publish a new upstream version until the submodule points to the
  intended immutable upstream release commit.

## Contribution policy

Humans own issue and pull request discussion and every pull request template
section marked `HUMAN ONLY`. AI may help with implementation, tests, a
Conventional Commit title, and template sections that aren't marked
`HUMAN ONLY`. Refer to
[`upstream/docs/developer/genai.md`](upstream/docs/developer/genai.md) and the
upstream pull request template for the full policy.

Don't edit changelog files manually. Use Conventional Commit messages with a
capitalized description, for example:

```text
fix(amtm): Preserve configuration during upgrades
```
