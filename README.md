# Alloy for Asuswrt-Merlin and AMTM

This repository packages [Grafana Alloy](https://github.com/grafana/alloy) for
Asuswrt-Merlin routers managed with AMTM. The first supported target is the
ASUS RT-BE88U (`linux/arm64`).

The repository intentionally contains only the downstream AMTM integration.
The unmodified Alloy source is pinned as the `upstream/` Git submodule.

## Project context

The primary repository is
[`yongaqcom/alloy-amtm`](https://github.com/yongaqcom/alloy-amtm). It tracks
only the files required to build, package, test, document, and release the AMTM
distribution. Don't copy Grafana Alloy source into the primary repository.

The `upstream/` submodule points to
[`grafana/alloy`](https://github.com/grafana/alloy) at commit
`0dffb9f2829cf6ee5e527568e22a5ba82cb5dd5f`. The source reports Alloy version
`1.19.0`. The authoritative source ref and commit are recorded in
[`packaging/amtm/UPSTREAM_VERSION`](packaging/amtm/UPSTREAM_VERSION). That file
currently records a provisional `main` snapshot; a future upstream update
should pin a final Alloy release tag.

The current downstream release is
[`v1.19.0-amtm.1`](https://github.com/yongaqcom/alloy-amtm/releases/tag/v1.19.0-amtm.1).
Its workflow builds a static ARM64 binary, validates it under QEMU, runs the
shell packaging tests, and publishes the archive with `SHA256SUMS`. Automated
checks pass, but physical ASUS RT-BE88U validation and the 24-hour soak test
remain outstanding. Treat hardware support as provisional until those checks
pass.

Use `vX.Y.Z-amtm.N` for releases, where `X.Y.Z` identifies the upstream Alloy
version and `N` identifies a downstream packaging revision. A push to `main`
builds an Actions artifact. Only a pushed `v*-amtm.*` tag creates a GitHub
Release.

## Clone

```sh
git clone --recurse-submodules https://github.com/yongaqcom/alloy-amtm.git
cd alloy-amtm
```

For an existing clone, initialize the source checkout with:

```sh
git submodule update --init --recursive
```

## Layout

- `upstream/` - pinned, unmodified `grafana/alloy` source
- `packaging/amtm/` - installer, service, configuration, and package builder
- `tests/amtm/` - downstream packaging tests
- `.github/workflows/build-amtm.yml` - static ARM64 build and release workflow
- `docs/amtm/` - installation notes, engineering findings, and update runbook

Keep changes outside `upstream/`. Update the submodule gitlink and
`packaging/amtm/UPSTREAM_VERSION` together when adopting a new Alloy release.
For current validation gaps and support boundaries, refer to
[`docs/amtm/FINDINGS.md`](docs/amtm/FINDINGS.md).

See the [AMTM installation guide](docs/amtm/README.md) for installation and
operation. Maintainers should use the
[upstream update runbook](docs/amtm/UPSTREAM.md) when changing the pinned Alloy
version.
