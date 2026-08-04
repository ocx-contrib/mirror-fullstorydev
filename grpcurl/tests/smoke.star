# grpcurl smoke test.
#
# grpcurl is a NETWORK tool ("like cURL, but for gRPC"), but it has a genuine
# OFFLINE surface and this test uses only that — no socket is ever opened.
# From its own `--help`:
#
#   The 'address' is only optional when used with 'list' or 'describe' and a
#   protoset or proto flag is provided.
#
# So `-proto <file> list` and `-proto <file> describe <symbol>` run grpcurl's
# in-process protobuf compiler over a local `.proto` and render the resulting
# descriptors. That is a real functional operation on hermetic input — parse,
# build a descriptor set, resolve a symbol, re-render it — not a flag probe,
# and it exercises the bulk of the binary that is not the gRPC transport.
#
# Every assertion below is on a COMPUTED RESULT (a symbol the parser resolved
# out of input written here, or a field the descriptor renderer emitted), never
# on help or version prose.
#
# Measured on the real linux/amd64 assets for all four in-range versions
# (1.9.0, 1.9.1, 1.9.2, 1.9.3) before this file was written:
#   * `--version` prints `grpcurl vX.Y.Z` on **stderr**, NOT stdout — measured,
#     and it reds an otherwise-correct stdout assert on every leg at once:
#         $ grpcurl --version 2>/dev/null | od -c   → empty
#         $ grpcurl --version 2>&1 1>/dev/null      → grpcurl v1.9.3
#     (Go's `flag` package convention. All the FUNCTIONAL output below is on
#     stdout, verified the same way — only the version banner is split off.)
#     Shape regex only, never the string
#   * describe/list output carries ZERO ESC bytes (no colorization to defeat)
#   * a malformed .proto exits 1 — a POSITIVE code, so it needs no
#     unix-255 / windows-(-1) branch
#   * behaviour is byte-identical across all four versions
#   * NO GOOS/GOARCH anywhere in the version output or the binary
#     (`strings -a grpcurl | grep -c 'linux/amd64'` → 0), so the free
#     platform-identity assert other Go tools allow is NOT available here

TOOL = "grpcurl.exe" if ocx.target_platform.os == ocx.os.Windows else "grpcurl"

PROTO = "ocxsmoke.proto"
BAD_PROTO = "ocxsmoke_bad.proto"

# HOME is pinned to scratch as insurance for the container legs, where it can
# be unset or unwritable. Measured: grpcurl does NOT depend on it (it runs
# clean with HOME unset and with HOME=/nonexistent), so this costs nothing —
# and grpcurl is a pure-Go binary that shells out to no cargo/rustc, so the
# rustup-toolchain hazard of a redirected HOME does not apply. NO_COLOR is
# belt-and-braces: the output was measured colourless already.
ENV = {"HOME": ocx.scratch_root, "NO_COLOR": "1"}

# ─── Tier 1 + 2: liveness and version SHAPE ────────────────────────────────
# Banner is on STDERR (see the measurement above), so stdout stays empty here.
r_version = ocx.run(TOOL, "--version", env=ENV)
expect.ok(r_version)
expect.matches(r_version.stderr, r"\d+\.\d+\.\d+")
expect.eq(r_version.stdout, "")

# ─── Hermetic input ────────────────────────────────────────────────────────
# Both files are written here, so nothing outside scratch is read. The symbol
# names are deliberately unique to this test — a binary that emitted them
# without parsing this file would have to have invented them.
ocx.write_file(PROTO, """syntax = "proto3";
package ocxsmoke;

message PingRequest { string payload = 1; }
message PingResponse { string payload = 1; int32 count = 2; }

service OcxSmokeService {
  rpc Ping (PingRequest) returns (PingResponse);
  rpc Echo (PingRequest) returns (PingResponse);
}
""")

ocx.write_file(BAD_PROTO, """syntax = "proto3";
this is not valid protobuf @@@
""")

# ─── Tier 3a: list the services the parser found ───────────────────────────
# Counts, not exit 0 — a list command that found nothing also exits 0.
r_services = ocx.run(TOOL, "-proto", PROTO, "list", env=ENV)
expect.ok(r_services)
expect.eq(r_services.stdout.count("ocxsmoke.OcxSmokeService"), 1)

# ─── Tier 3b: list the methods of that service ─────────────────────────────
# Exactly the two rpcs declared above, and no third.
r_methods = ocx.run(TOOL, "-proto", PROTO, "list", "ocxsmoke.OcxSmokeService", env=ENV)
expect.ok(r_methods)
expect.eq(r_methods.stdout.count("ocxsmoke.OcxSmokeService."), 2)
expect.eq(r_methods.stdout.count("ocxsmoke.OcxSmokeService.Ping"), 1)
expect.eq(r_methods.stdout.count("ocxsmoke.OcxSmokeService.Echo"), 1)

# ─── Tier 3c: descriptor round-trip on a MESSAGE ───────────────────────────
# The strongest check here: grpcurl re-renders the message from the descriptor
# it built, so field types, names AND tag numbers all have to survive the
# parse. A truncated or wrong-flavour binary cannot produce this.
r_msg = ocx.run(TOOL, "-proto", PROTO, "describe", "ocxsmoke.PingResponse", env=ENV)
expect.ok(r_msg)
expect.eq(r_msg.stdout.count("string payload = 1;"), 1)
expect.eq(r_msg.stdout.count("int32 count = 2;"), 1)

# ─── Tier 3d: descriptor round-trip on a METHOD ────────────────────────────
# Resolves the rpc's request/response types back to fully-qualified names.
r_rpc = ocx.run(TOOL, "-proto", PROTO, "describe", "ocxsmoke.OcxSmokeService.Ping", env=ENV)
expect.ok(r_rpc)
expect.eq(r_rpc.stdout.count(".ocxsmoke.PingRequest"), 1)
expect.eq(r_rpc.stdout.count(".ocxsmoke.PingResponse"), 1)

# ─── Negative control 1: malformed input must be REJECTED ──────────────────
# Without this, every assertion above would also pass against a tool that
# merely echoed plausible text. Exit 1 is asserted exactly (measured on all
# four in-range versions); it is a POSITIVE code, unaffected by the
# unix-255 / windows-(-1) split that bites negative exit codes.
r_bad = ocx.run(TOOL, "-proto", BAD_PROTO, "list", env=ENV)
expect.eq(r_bad.exit_code, 1)
expect.eq(r_bad.stdout.count("ocxsmoke.OcxSmokeService"), 0)

# ─── Negative control 2: an unknown symbol must not resolve ────────────────
# Proves the symbol lookup in 3c/3d is a real resolution against the parsed
# descriptor set, not an echo of the argument.
r_unknown = ocx.run(TOOL, "-proto", PROTO, "describe", "ocxsmoke.NoSuchSymbol", env=ENV)
expect.eq(r_unknown.exit_code, 1)
expect.eq(r_unknown.stdout.count("is a message"), 0)
