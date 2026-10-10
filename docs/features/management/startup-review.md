# Startup action review

Startup record actions now name the enable or disable effect, explain future sign-in behavior and block unavailable or conflicting records. Confirmation sends only the selected id, desired enabled state and explicit consent. Three fixture checks passed for eligibility, cancellation and exact requests. No host startup entry was changed; built interaction remains pending.

The existing engine saves the original current-user Run command before removal and restores only where no newer entry occupies the name. This UI change does not add an atomic registry compare-and-swap or cover machine and startup-folder entries. Records may change after a read; refresh before reviewing a new action.
