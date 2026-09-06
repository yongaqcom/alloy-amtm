# Track Grafana Alloy upstream releases

This repository keeps downstream AMTM code separate from Alloy. The
`upstream/` Git submodule points directly at
[`grafana/alloy`](https://github.com/grafana/alloy), so upstream source isn't
copied into this repository and must never be modified here.

## Version policy

An AMTM release derived from Alloy `vX.Y.Z` is tagged `vX.Y.Z-amtm.N`, where
`N` starts at `1` and increases only for AMTM packaging fixes against the same
Alloy release. The selected ref and immutable commit are also recorded in
[`UPSTREAM_VERSION`](../../packaging/amtm/UPSTREAM_VERSION).

The initial `v0.1.0-amtm.1` release predates this mapping.

## Select a release

Import final upstream release tags, not arbitrary commits from `main`. Fetch
the tags in the submodule and inspect the candidate:

```sh
git submodule update --init
git -C upstream fetch origin --tags --prune
new_ref=v1.20.0
git -C upstream show --no-patch --decorate "$new_ref"
new_commit=$(git -C upstream rev-parse "$new_ref^{commit}")
```

Read the upstream release notes and inspect changes to the Go toolchain,
`collector/`, generated OpenTelemetry Collector code, build tags, CGO use, and
Linux kernel assumptions. Asuswrt-Merlin doesn't guarantee systemd, cgroups,
eBPF/BTF, Docker, Kubernetes, or a conventional server `/sys` layout.

## Update the submodule

Start from a clean checkout and create one update branch:

```sh
git switch main
git pull --ff-only origin main
git submodule update --init
git status --short                         # must print nothing
git switch -c update/alloy-v1.20.0
git -C upstream switch --detach "$new_commit"
```

Update `packaging/amtm/UPSTREAM_VERSION` with the selected ref, commit, and UTC
date. The commit recorded there must equal the submodule commit:

```sh
git -C upstream rev-parse HEAD
awk -F= '$1 == "commit" { print $2 }' packaging/amtm/UPSTREAM_VERSION
git add upstream packaging/amtm/UPSTREAM_VERSION
git diff --cached --submodule=log
git diff --check
git commit -m "chore(amtm): Update Alloy to v1.20.0"
```

Do not commit changes inside `upstream/`. If a downstream source patch ever
becomes necessary, keep it as an explicit patch in this repository and apply
it during the build so the submodule remains an auditable upstream checkout.

## Validate and publish

At minimum, the update must pass the gates in
`.github/workflows/build-amtm.yml`: shell checks, a static ARM64 build, ELF
inspection, QEMU startup and configuration validation, packaging, and checksum
verification. Then test upgrade, rollback, boot ordering, resource use, and a
24-hour soak on a physical RT-BE88U.

After human review and device validation, fast-forward `main`, create an
annotated `vX.Y.Z-amtm.N` tag, and push it. Never move or reuse a published
tag. A packaging-only correction increments `N`; an Alloy defect should wait
for or move to an upstream patch release.

## Update checklist

- [ ] Selected a final upstream release tag and reviewed its release notes.
- [ ] Updated only the `upstream` gitlink and `UPSTREAM_VERSION`.
- [ ] Confirmed the recorded commit equals `git -C upstream rev-parse HEAD`.
- [ ] Passed shell, static ELF, QEMU, configuration, and packaging checks.
- [ ] Tested upgrade and rollback on an RT-BE88U.
- [ ] Completed the 24-hour hardware soak test.
- [ ] Tagged with `vX.Y.Z-amtm.N` and verified both release assets.
