# Track Grafana Alloy upstream releases

This repository is a thin downstream distribution of
[`grafana/alloy`](https://github.com/grafana/alloy). Import released upstream
tags rather than arbitrary commits from `main`. Keep router-specific changes in
the small set of paths listed below so each import remains reviewable.

## Version policy

An AMTM release derived from Alloy `vX.Y.Z` is tagged `vX.Y.Z-amtm.N`, where
`N` starts at `1` and increases only for AMTM packaging fixes against the same
Alloy release. Examples:

```text
v1.20.0-amtm.1  First AMTM build based on Alloy v1.20.0
v1.20.0-amtm.2  AMTM-only fix; Alloy source is still v1.20.0
v1.20.1-amtm.1  First AMTM build based on Alloy v1.20.1
```

The initial `v0.1.0-amtm.1` release predates this mapping. The authoritative
upstream ref and commit for the checked-in source are recorded in
[`UPSTREAM_VERSION`](../../packaging/amtm/UPSTREAM_VERSION).

## Watch for releases

Watch Grafana Alloy's GitHub releases, or query the latest non-prerelease from
a maintainer workstation:

```sh
gh api repos/grafana/alloy/releases/latest \
  --jq '{tag: .tag_name, published: .published_at, url: .html_url}'
```

Do not import a release candidate unless the AMTM release is explicitly marked
as a prerelease. Security releases take priority over the normal update
cadence.

For each release, read the upstream release notes and inspect changes to:

- `go.mod` and the required Go toolchain
- `collector/` and generated OpenTelemetry Collector code
- `Makefile` and `build-tools/make/packaging.mk`
- build tags, CGO use, and embedded helper binaries
- configuration validation and `run` command flags
- Unix exporter collectors and Linux kernel assumptions

Pay particular attention to a higher minimum Linux kernel, new CGO/native
dependencies, or components that assume systemd, cgroups, eBPF/BTF, Docker, or
Kubernetes. Those facilities aren't guaranteed by Asuswrt-Merlin.

## Configure the remotes

A fresh clone has only the downstream `origin`. Add the canonical repository
once, then fetch its tags:

```sh
git remote add upstream https://github.com/grafana/alloy.git
git fetch upstream --tags --prune
git remote -v
```

If `upstream` already exists, only the fetch is needed. Confirm the selected
tag and resolve its immutable commit:

```sh
new_ref=v1.20.0
git show --no-patch --decorate "$new_ref"
new_commit=$(git rev-parse "$new_ref^{commit}")
```

Use the exact release tag, never a moving branch name, as `new_ref`.

## Import a release

The downstream repository is maintained as a source snapshot. The procedure
below replaces upstream-owned files while carrying the AMTM patch forward.
Start from a clean checkout because `git read-tree --reset -u` deliberately
replaces tracked files.

```sh
git switch main
git pull --ff-only origin main
git status --short                         # must print nothing
git switch -c update/alloy-v1.20.0
mkdir -p .tmp

old_commit=$(awk -F= '$1 == "commit" { print $2 }' \
  packaging/amtm/UPSTREAM_VERSION)

git diff --binary "$old_commit" HEAD -- \
  .gitignore \
  README.md \
  .github/workflows/build-amtm.yml \
  docs/amtm \
  packaging/amtm \
  tests/amtm \
  >.tmp/amtm-downstream.patch

git read-tree --reset -u "$new_commit"
git apply --3way .tmp/amtm-downstream.patch
```

The downstream-owned paths are:

```text
.github/workflows/build-amtm.yml
docs/amtm/
packaging/amtm/
tests/amtm/
```

`README.md` contains only the AMTM notice near the top, and `.gitignore`
contains `/.tmp/`. Resolve conflicts by retaining the new upstream content and
reapplying those two small downstream additions. Never keep an old upstream
file merely to avoid a conflict.

Update `packaging/amtm/UPSTREAM_VERSION` with the selected ref, commit, and UTC
import date. Then inspect the entire update, including upstream files deleted
or added by the release:

```sh
git status --short
git diff --stat HEAD
git diff -- packaging/amtm/UPSTREAM_VERSION
git diff --check
```

Commit the import using the repository's conventional commit format:

```sh
git add -A
git commit -m "chore(amtm): Update Alloy to v1.20.0"
```

## Validate the update

At minimum, the update must pass the same gates as
`.github/workflows/build-amtm.yml`:

1. ShellCheck and the installer lifecycle test.
2. A `CGO_ENABLED=0`, `GOOS=linux`, `GOARCH=arm64`, `GOARM64=v8.0` build.
3. ELF inspection confirming AArch64 and no program interpreter.
4. `alloy --version` and configuration validation under ARM64 emulation.
5. Package checksum generation and verification.

Push the update branch and wait for CI:

```sh
git push -u origin update/alloy-v1.20.0
gh run watch --repo yongaqcom/alloy-amtm --exit-status
```

Before release, install the candidate archive on an RT-BE88U and verify:

- configuration validation and service start/restart/stop
- cold boot after `/opt` is mounted
- self metrics and every supported metrics/logs/OTLP pipeline
- idle and loaded RSS, CPU use, storage use, and log rotation
- upgrade from the previous AMTM release and automatic rollback on failure
- a 24-hour soak test without router instability

QEMU validates the instruction set and startup path, but it can't validate the
Broadcom kernel, the router's `/proc` and `/sys`, USB durability, or Entware
boot ordering.

## Publish

After review and real-device validation, fast-forward `main`, tag the exact
commit, and push the tag:

```sh
git switch main
git merge --ff-only update/alloy-v1.20.0
git push origin main
git tag -a v1.20.0-amtm.1 -m "Alloy AMTM v1.20.0-amtm.1"
git push origin v1.20.0-amtm.1
```

The tag triggers the build workflow. It must publish both
`alloy-amtm-linux-arm64.tar.gz` and `SHA256SUMS`. Verify the release assets:

```sh
gh release view v1.20.0-amtm.1 \
  --repo yongaqcom/alloy-amtm \
  --json url,assets
```

Don't move or reuse a published tag. If packaging is defective, fix it in a
new commit and publish `-amtm.2`. If the Alloy source is defective, return to
the previous known-good AMTM release while waiting for an upstream patch.

## Update checklist

- [ ] Selected a final upstream release tag and recorded its commit.
- [ ] Reviewed release notes, toolchain, kernel, CGO, and component changes.
- [ ] Imported upstream-owned files and reapplied only the AMTM patch.
- [ ] Updated `UPSTREAM_VERSION`.
- [ ] Passed shell, static ELF, QEMU, config, and packaging checks.
- [ ] Tested upgrade and rollback on an RT-BE88U.
- [ ] Completed the 24-hour hardware soak test.
- [ ] Tagged with `vX.Y.Z-amtm.N` and verified both release assets.
