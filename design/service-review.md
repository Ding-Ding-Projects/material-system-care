# Service review state contract

Extend the established inspection workspace composition: application bar, bounded content column, explicit read action, state selector, search and expandable records. Use official Flutter Material components. This document describes implementation intent, not rendered evidence or design parity.

States: idle (no query), reading (read disabled and progress visible), completed (sorted factual records), filtered-empty, unavailable (old rows removed), and disposed (late completion ignored). No mutation path is part of this surface. Service names and platform state values remain literal rather than translated identifiers.

Operation status transitions use the existing reduced-motion-aware component; expansion and interaction feedback belong to official controls. The full matrix and per-element motion verification remain pending.
