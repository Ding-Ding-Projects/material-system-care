# Narrow observed Flutter frame verification

Run:

```text
node scripts/verify-observed-flutter-frame.mjs <repository-root> <private-run-root> <private-bundle-root> <manifest-relative-to-repository>
node scripts/test-observed-flutter-frame.mjs
```

This verifier binds source, bundle bytes, frame bytes, and the native
capture-scoped Flutter diagnostic snapshot. It is not the global UI-evidence
promotion validator, a visual review, or an independent observation of handler
execution. It does not establish native compositor, complete application error,
input-action success, or teardown success. A hash binds the supplied record; it
does not make its claims true.

The manifest contains only this fixed schema and portable relative references,
with no absolute machine paths, raw errors, stacks, or free-form descriptions:

```json
{
  "schemaVersion": 1,
  "scope": "observed-flutter-hooks-and-bytes",
  "sourceCommit": "<40 lowercase hexadecimal characters>",
  "buildReceiptSha256": "<64 lowercase hexadecimal characters>",
  "bundleManifestSha256": "<64 lowercase hexadecimal characters>",
  "frames": [{
    "png": "output/frame.png",
    "sidecar": "output/frame.png.json",
    "sha256": "<PNG SHA-256>",
    "sidecarSha256": "<sidecar SHA-256>",
    "sequence": 0
  }],
  "evidence": [{
    "role": "teardown",
    "path": "teardown.json",
    "sha256": "<record SHA-256>"
  }]
}
```

Frame and evidence references resolve under the private run root. Build and
bundle manifests resolve under the private bundle root. The public manifest
itself resolves under the repository root. References cannot escape those
roots. `evidence` accepts optional `action` and `teardown` records, at most 256;
their hashes are checked, but their schemas or outcome claims are not accepted
by this verifier. An empty evidence list makes no action or teardown claim.

The source commit and tree must exist locally. The build receipt must name that
commit and matching source/index trees. Its build-manifest hash must match the
source blob with either its original bytes or ordinary Windows CRLF checkout
line endings. Bundle files must match the full sorted manifest inventory,
lengths, individual hashes, aggregate hash, and executable hash. The four
receipt/manifest files excluded by the producer remain excluded from its
aggregate. Symbolic bundle entries are rejected.

Each frame must have an exact PNG and sidecar digest, matching IHDR dimensions,
bounded size, sequence and timestamps, and an observed diagnostic snapshot.
The snapshot must have exactly the two documented hooks, `healthy: true`, and
numeric zero framework/platform/dropped counts. Its sequence and completion
must match the frame, and its start must be between build completion and frame
start. Missing, legacy, unhealthy, nonzero, malformed, or extra diagnostic
fields are rejected. Native receipts with nonzero observed errors can be valid
capture records, but fail this narrower zero-observed-error acceptance rule.

PNG signature and IHDR checks are not a full decoder or pixel inspection.
Timestamp checks validate consistency of supplied observations, not an external
clock attestation. Existing captures are never modified. Only real receipts
supplied by the capture owner may support a live-evidence result; the test
script creates explicitly synthetic fixtures and cannot establish live proof.

The narrow verifier accepts up to 64 distinct frames with sequences 0 through 63. Sequence 64 and a 65-frame inventory are rejected. Filename/sequence binding, exact PNG and sidecar hashes, source/bundle verification, two-hook diagnostic coverage and privacy checks remain unchanged. This extension does not establish acceptance by a separate promotion validator.
