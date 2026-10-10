# Native verification fixtures

A native task-owned graceful-close fixture is being added under scripts/native-fixture. It creates one ordinary window, reads no user data, performs no host action and self-exits after five minutes. It is built through build.bat /s --target=native --resource-only and is not a production product surface or installer payload. Launch it only on the explicitly owned hidden desktop. Actual UI-close verification is pending; do not claim a close from source or compilation alone.

The five-minute timeout prevents a forgotten fixture from remaining open indefinitely. A graceful-close verdict must occur before that deadline and bind the selected PID/start identity to the exact fixture executable. Preserve launch, input, result and absence receipts. A timer exit or unexplained disappearance is not proof that the product closed it. Never target user applications or the visible desktop.
