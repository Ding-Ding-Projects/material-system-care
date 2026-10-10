# Service review

Open **Tools > Services** and choose **Read services**. Nothing is collected automatically. Filter loaded records by text or by Running, Stopped or Paused state; All states retains transitional or unfamiliar reported values. Expand a service for its exact name, state and configured start type.

The existing services.list engine method uses a fixed read-only Get-Service projection. It excludes executable command lines, accounts and credentials. Service names and display names can still identify local products, so populated captures require private handling. State can change after collection. Start type alone does not establish whether a service is needed or safe to disable.

No start, stop, disable or reconfiguration control exists. This is an inspection workflow, not blanket optimization. Invalid, duplicate or oversized UI responses are rejected in full; a failed refresh clears older rows. Single-record PowerShell objects are normalized without guessing identities. Unknown fields are not displayed. Records are transient and are not automatically persisted or uploaded.

## Motion and accessibility

Official Material controls own focus, press, selection and expansion feedback. OperationMotion transitions among idle, reading, result and unavailable states and respects reduced motion. A wrapping action row and scrollable record surface adapt to width; result text remains selectable where useful. Complete keyboard, high-scale, language, export and appearance contracts remain tracked separately and unverified.

## Verification

Four focused widget checks passed for isolated entry, explicit singleton collection/filtering/stale-result clearing, duplicate rejection and late completion after disposal. Root engine and desktop builds passed at 74b1f41232e987687524c0aa1ef228ede9e06ed8. Four focused widget checks passed. A genuine hidden-desktop run collected 294 service records, filtered the loaded set, expanded one record and excluded that stopped record under the Running filter. The observed count is account- and time-specific, not an exhaustive access guarantee. All owned bundle processes were absent and the hidden desktop closed. Populated frames remain private; only the inspected idle image is public. The narrow verifier checked 210 bundle files and rejected an altered input-receipt hash before restored evidence passed. Complete language, accessibility, appearance and export contracts remain unverified. The isolated --services capture selector opens the production widget without persisted settings; it never injects service records.

## Enlarged bilingual selection

The state selector uses expanded width and intrinsic item height so selected bilingual text can wrap instead of being forced into a single fixed-height item. A focused 800x600/text-scale-2 fixture passes after reproducing the original overflow. Identical rebuilt runtime verification remains pending.
