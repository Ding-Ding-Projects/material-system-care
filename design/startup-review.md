# Startup review workspace

The primary surface is a working list of current-user sign-in entries and saved restoration records. It uses the registered Material 3 AppBar, SearchBar, labelled state selector, cards, explicit outlined review actions, AlertDialog and progress/feedback components.

The initial state reads nothing until Refresh records is activated. Cards distinguish enabled entries, saved disabled entries, read-only entries and restoration conflicts. A command is selectable within an expandable detail section. No internal revision or journal path is displayed.

Every mutation begins with one named entry and a description of future sign-in effects. Cancel sends no mutation. Confirmation sends only the selected identifier, reviewed revision, desired state and explicit consent. A changed record refreshes without automatically repeating the mutation. A failed refresh removes stale actions. The entire workspace scrolls as one surface, including at the documented 800×600 minimum and doubled bilingual text.

Material Designer was unavailable in this environment, so this checked-in specification is the implementation handoff. It is not rendered evidence. The real theme, scale, focus, action and reduced-motion matrix remains to be captured and verified.
