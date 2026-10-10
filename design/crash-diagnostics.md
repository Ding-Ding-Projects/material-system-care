# Crash diagnostics workspace contract

This additive workflow uses the existing Flutter Material 3 shell and registered controls. It opens from Tools using a Material route, rather than adding another rail destination. It is a task workspace, not a catalogue or promotional surface.

States: idle, collecting, event inventory, empty inventory, collection unavailable, stop-code lookup, invalid lookup, expanded event detail, and navigation away during a pending request. Production states contain actual engine results; synthetic fixtures are never labelled live.

Controls: AppBar, FilledButton, OutlinedButton, TextField, DropdownButtonFormField, Card, ExpansionTile, ListTile, Tooltip, LinearProgressIndicator and Divider. Noninteractive layout primitives arrange the controls. Material controls own focus, hover, press and selection feedback. OperationMotion transitions identify request state; AnimatedSize reveals lookup output. Platform or saved reduced-motion preferences suppress those explicit transitions. Sounds remain off.

Layout: a scrollable, width-constrained workspace with wrapping action rows. The normal desktop is 1280 × 720; validate the existing supported minimum, English/Cantonese/bilingual, light/dark, and 100/125/150/200 percent scales before visual completion. Real built reference images remain pending because the earlier hidden Flutter capture returned blank pixels. No mock or generated image is accepted as runtime evidence.
