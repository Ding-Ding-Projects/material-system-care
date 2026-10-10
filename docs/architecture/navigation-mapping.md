# Navigation mapping

Desktop source `d8280ec6bfd1396b3f1f90ed73b2c6cf7be9359e` declares ten visible destinations. This table maps those destinations to the fixed planned workspaces without deleting requirements or claiming that sharing a destination completes them.

| Actual destination | Fixed inventory surfaces | Source-linked behavior and remaining distinction |
| --- | --- | --- |
| Overview | `desktop.overview`; planned `desktop.system` | Live snapshot and engine manifest version are linked. A complete hardware workspace and provenance-bound updated-at value remain missing. |
| Storage | `desktop.storage`; planned `desktop.care`, `desktop.recovery`, `desktop.files` | Selected-folder analysis, duplicates, temporary-file cleanup and recovery history are linked. Other cleanup, recovery and file workflows remain separate unmet requirements. |
| Apps | `desktop.applications` | General inventory and update text remain available. Explicit WinGet discovery now supplies structured exact package IDs for contextual reviewed actions; registry/AppX rows still do not invent them. |
| Startup | `desktop.startup`; planned `desktop.performance` | Added explicit Startup surface inventory. Current-user Run entries exist; a performance/boost workspace is not thereby complete. |
| Protection | `desktop.security`; planned `desktop.privacy` | Defender/firewall state and confirmed quick scan handoff exist. No independent detection engine, vault, browser interception or privacy workspace parity is established. |
| Drivers | `desktop.drivers` | Driver-store inventory and selected export exist. Online update catalogue, UI INF installation, rollback and restore remain unverified or missing. |
| Tools | `desktop.tools`; planned `desktop.toolbox` | Hash, text/JSON conversion, password and network forms exist. The 24-tool reference toolbox is not replaced by these four editors. |
| Activity | `desktop.history` | Local operation history and recovery navigation are linked. Full version history and universal exports remain unproved. |
| Settings | `desktop.settings` | Settings controls and local vocabulary cache source exist. Toggles alone do not implement narration, scheduling, full appearance editing or other underlying features. |
| Help | `desktop.docs` | Inline help exists. Complete searchable offline feature documentation remains a separate contract. |

`desktop.launcher`, download start/progress/completion, confirmation and notifications remain explicitly inventoried. Public Home, feature, download and settings surfaces retain their own independent requirements. Planned workspaces are not silently removed because the present navigation groups them differently.

The matrix now contains 28 explicit surfaces and 1,932 surface/contract rows, including Tools > Blue-screen diagnostics. Every universal row remains unimplemented/unverified until its implementation, localization, persistence, focused tests, real built interaction and capture are independently reviewed. No route name, source table or disabled control satisfies those proof boundaries.
