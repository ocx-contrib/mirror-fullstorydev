# NOTICE

This repository packages and redistributes upstream
[grpcurl](https://github.com/fullstorydev/grpcurl).

The Apache-2.0 license covers the OCX pipeline files authored here. It does
**not** cover upstream-derived assets — the grpcurl binaries published to
`ghcr.io/ocx-contrib/fullstorydev/grpcurl` are **MIT**-licensed, copyright
FullStory, Inc. and the grpcurl contributors, and each release archive ships
upstream's own `LICENSE` file alongside the binary.

Verified at the license gate:

```console
$ gh api repos/fullstorydev/grpcurl/license --jq '{spdx: .license.spdx_id, holder: .license.name}'
{"name":"MIT License","spdx":"MIT"}
```

MIT is permissive and grants redistribution outright, so no source-conveyance
obligation attaches to this mirror.

The logo shipped here (`logo.svg` / `logo.png`) is an original mark authored for
this catalog entry — upstream publishes no logo of its own. "FullStory" is a
trademark of FullStory, Inc.; it is used here nominatively to identify the
origin of the mirrored software, and this mirror is not affiliated with or
endorsed by FullStory, Inc.
