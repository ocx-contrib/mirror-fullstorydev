# mirror-fullstorydev

OCX mirrors for [Engineering at Fullstory](https://github.com/fullstorydev)
tooling. One repository, one spec directory per package.

| Package | Spec | Publishes to | Announced as |
|---|---|---|---|
| grpcurl | [`grpcurl/mirror.yml`](grpcurl/mirror.yml) | `ghcr.io/ocx-contrib/fullstorydev/grpcurl` | [`ocx.sh/fullstorydev/grpcurl`](https://index.ocx.sh/fullstorydev/grpcurl) |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

## Layout

`mirror-base.yml` at the root holds the repo-wide policy every spec inherits
via `extends:`. `extends:` is a **shallow** merge — a spec that sets a
top-level key replaces that block whole. `platforms:` is deliberately absent
from the base: the container matrix is downstream of each package's own libc
measurement, so both live together in the package's spec.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `grpcurl/mirror.yml` | hand | `ocx-mirror package pipeline generate ci --spec grpcurl/mirror.yml` |
| `grpcurl/tests/smoke.star` | hand | — |
| `grpcurl/metadata.json`, `grpcurl/CATALOG.md`, `logo.*` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

Name **every** spec on the regenerate command — `--spec` appends rather than
replaces, so a command naming a subset silently stops rendering the rest while
staying green.

The repo root is inferred from the enclosing git repository, so `--repo-root`
is needed only when generating outside a checkout.

CI fails on drift via `ocx-mirror package pipeline generate ci --check`.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index PR from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of
scope; see [`NOTICE.md`](NOTICE.md).
