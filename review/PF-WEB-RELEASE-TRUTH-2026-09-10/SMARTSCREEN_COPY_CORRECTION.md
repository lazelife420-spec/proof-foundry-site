# SmartScreen Copy Correction (F12)

**Audit Date:** 2026-09-10 (2026-09-11 UTC)

---

## 1. Finding

In `lights-out.html`, the SmartScreen FAQ answer previously stated:
> *"Because the build isn't code-signed yet. Windows shows this warning for any unsigned executable, regardless of how it was tested. Verify the SHA-256 hash above before deciding whether to proceed."*

This assertion was overgeneralized; Microsoft SmartScreen reputation checks evaluate reputation, certificate presence, and telemetry, rather than issuing automatic warnings exclusively for unsigned files.

## 2. Correction Applied

Replaced with accurate conditional copy:
> *"Because this build is not code-signed, Windows may show an unrecognized-app or "Windows protected your PC" warning, depending on Windows security and reputation checks. Verify the published SHA-256 before deciding whether to run it."*
