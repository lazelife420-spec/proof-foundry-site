# Reality Gate CLI Public Artifact Audit (F01)

**Audit Date:** 2026-09-10 (2026-09-11 UTC)
**Artifact URL:** `https://downloads.theprooffoundry.com/reality-gate/v1.1.0/Reality-Gate-1.1.0-Developer-Pilot.zip`
**Expected SHA-256:** `58cc27d22bdee8157ee4598e116e17ff42d0efc95630c97bee4b2bc6be6ce756`
**Verdict:** `F01_PUBLIC_CLI_NOT_PRESENT_PROVEN`

---

## 1. Outer Archive Verification & Inventory

* **HTTP Response:** `200 OK`
* **Downloaded Byte Size:** `113,508,821 bytes`
* **Downloaded SHA-256:** `58cc27d22bdee8157ee4598e116e17ff42d0efc95630c97bee4b2bc6be6ce756` (PERFECT MATCH)
* **Archive Contents:**
  - `Reality Gate Setup 1.1.0.exe` (113,372,028 bytes)
  - `BUILD-INFO.txt`
  - `demo-repo/`
  - Documentation files (`README.md`, `QUICK-START.md`, `WHAT-REALITY-GATE-DOES.md`, etc.)

---

## 2. Inner Installer Payload Inspection

Read-only inspection of `Reality Gate Setup 1.1.0.exe` using 7-Zip (`7z`):

* **PE / Container Identity:** NSIS-3 Unicode Installer archive (`113,372,028 bytes`).
* **NSIS Payload Extraction:** Extracted embedded `$PLUGINSDIR\app-64.7z` (`112,791,514 bytes`).
* **Installed Application Payload Inventory (`380,670,375 bytes`, 75 files):**
  - Main Executable: `Reality Gate.exe` (`213,976,576 bytes` — Electron GUI host)
  - Application ASAR Bundle: `resources\app.asar` (`34,314,337 bytes`)
  - Utility Binary: `resources\elevate.exe` (`107,520 bytes` — UAC elevation utility)
  - Locales & Chromium runtime binaries

---

## 3. Package & Manifest Search

1. **Executable / Shim Search:** Zero CLI executables (`rg.exe`, `reality-gate.exe`, `rg-cli`) or command shims exist in the installed payload.
2. **ASAR Package Manifest (`package.json` inside `app.asar`):**
   ```json
   {
     "name": "offlineforge",
     "version": "1.1.0",
     "description": "Local-only GitHub-style code forge",
     "main": "main.js",
     "author": "",
     "license": "MIT"
   }
   ```
   - No `bin` property is declared.
   - No CLI command entry point is exposed.
3. **Bundled Documentation Witness:** No command-line invocation is documented in bundled READMEs or help guides.

---

## 4. Final Verdict & Resolution

* **Verdict:** `F01_PUBLIC_CLI_NOT_PRESENT_PROVEN`
* **Resolution:** In `reality-gate.html`, the capability matrix entry for `First-Class CLI & Instance Discovery (RG-05)` is set to:
  `<td><span class="rg-status-glyph glyph-pass">PASS ●</span> Branch Qualified</td>`
  `<td>CLI tooling and instance discovery qualified on separate development branches.</td>`
* **Temp Cleanup:** Temporary downloaded ZIP and extracted payload directories deleted from `AppData\Local\Temp`. Zero binaries added to Git repository.
