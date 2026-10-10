# File-use workspace handoff

Extend the established Flutter desktop workspace composition. This is an actionable Tools child route, not a marketing surface or generic command form. Production implementation: desktop/lib/file_use.dart. Registered controls: AppBar, TextField, OutlinedButton, FilledButton, Card, LinearProgressIndicator, Divider and shared OperationMotion. Constrain the content to 1000 logical pixels with a scrollable list and wrapping actions.

States: untouched idle; chosen or typed path; native picker pending/cancel/unavailable; inspection pending; affected records; advisory empty result; invalid input; changing owner list; unavailable or malformed response. Native file picker remains an operating-system surface. Visible path and owner values are private runtime data.

Existing CopyScope carries English, Cantonese and bilingual preferences. Shared motion and AnimatedSize honor reduced motion. Verification tuples remain required: normal 1264x681 client area and documented minimum, light/dark, three language modes and 100/125/150/200 percent scale. No full parity or layout-matrix verdict is claimed. Source fixtures are not rendered design references; genuine built frames remain required.
