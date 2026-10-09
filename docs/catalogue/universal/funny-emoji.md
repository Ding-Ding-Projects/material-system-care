# Independent humor levels and dialog emoji switch

This mandatory contract is tracked independently from catalogue capabilities. Current status: **unimplemented or unreviewed**. Its entry in the [per-surface inventory](../../architecture/surface-completeness.json) is the authoritative reviewed status. This article is a requirement, not implementation evidence.

## Behavior and configuration

Expose independent humor-intensity and humor-frequency controls plus a persisted dialog emoji toggle. Emoji decorations must never change button labels, field labels or accessible names; disabled decorations preserve the same factual copy.

The desktop workspace and each public website surface must independently provide this behavior where the contract is surface-scoped. User choices must be persisted locally, discoverable in settings and command search, and support English, Cantonese and bilingual text. A sibling page or hidden route cannot supply proof for this surface.

## Failure and security boundaries

Unavailable platform capabilities must show the actual reason beside the affected action. No private input enters diagnostics, history, exported reports or public evidence. No control may report delivery, persistence, completion or recovery without observing the real result.

## Verification

The inventory requires exact implementation, documentation, localized text, persistence, focused tests, built interactions and genuine capture references. `node tests/coverage/universal.test.mjs` validates structure and exercises negative mutations. `node tests/coverage/universal.test.mjs --release` fails closed on incomplete applicable rows. The full behavior for this contract remains required; these inventory checks do not prove delivery.
