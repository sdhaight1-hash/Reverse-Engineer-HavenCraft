# HavenCraft demo — local evidence collection using REA

**Status as of 2026-11-11:** No official demo executable was available in the connected workspace. GitHub Actions official SteamCMD anonymous acquisition returned exit code **8**, classified `steam_app_download_error`, and downloaded **zero game files**. Therefore **REA has not analyzed HavenCraft's game code yet**. Do not label SteamDB technology detections as proven by local analysis.

## Legitimate paths to obtain the demo
- [Steam HavenCraft Demo](https://store.steampowered.com/app/5260550/) (app 5260550). This is free, but Steam may require a logged-in account/license. Do not attempt entitlement bypasses.
- [Official HavenCraft playtest signup](https://havencraft.dionicsoftware.com/playtest.html): the developer sends playtest download links to subscribers by email. This is a separate authorized distribution.
- If you already have the demo installed, use its **existing install directory**, not a duplicate download. Steam's UI can open it through Properties → Installed Files → Browse.

SteamDB/SteamRaw report the Windows entry executable `HavenCraft.exe`. The Steam package's latest public build in the 2026-10-19 record was **26045324**; treat current installed version as unknown until recorded from the installed manifest or game itself.

## Read-only Windows reconnaissance
This repository includes [`scripts/recon/inspect-installed-demo.ps1`](../../scripts/recon/inspect-installed-demo.ps1). It requires [REA](https://github.com/morluto/rea) CLI already installed. It examines an already-installed demo; it doesn't execute the game.

From the repository root in PowerShell, with the correct **existing** installation directory:

```powershell
.\scripts\recon\inspect-installed-demo.ps1 -GameDir "C:\Program Files (x86)\Steam\steamapps\common\HavenCraft Demo"
```

The path above is a **standard Steam example**, not a statement about the actual user's PC. The script checks that `HavenCraft.exe` exists and stops if missing; it does not install software or acquire any game content. REA's `inspect-desktop-application` identifies Unity runtime candidates, and `inspect-managed-artifact` can examine a discovered `Managed/Assembly-CSharp.dll` without running it.

**Private, local-only output:** `%LOCALAPPDATA%\ReverseHavenCraft\recon\private-*` files can contain internal game code/metadata and local paths. Keep them private, do not commit or upload to public repos. The script separately generates `shareable-install-fingerprint.json` with only selected file basenames, sizes, hashes and Mono/IL2CPP candidate flags. No recovered game art, audio, code or raw asset bundles are included.

## Read-only save archive reconnaissance
Steam's published cloud configuration describes Windows saves at:

```text
%USERPROFILE%\AppData\LocalLow\Dionic Software\HavenCraft\saves\*.zip
```

This is public distribution metadata, not a discovered local save. If a save is lawfully available, run:

```powershell
python scripts/recon/inspect_save_archive.py "C:\path\to\my-save.zip" --output "C:\path\to\save-inventory.json"
```

The analyzer only reads ZIP central directory metadata: file count, extensions, byte counts, CRC32 and hashed member names. It never extracts or reads any member content. Even a successful inventory **does not prove what serialization is inside the members**. Don't commit or redistribute save payloads without assessing private content.

## Next actual binary evidence gates
1. Record `HavenCraft.exe` SHA-256 and full build number.
2. REA desktop inspection identifies Unity Mono candidate (a real Assembly-CSharp reference) vs Unity IL2CPP candidate (metadata + native assembly) or unresolved runtime.
3. If a game managed assembly exists, inspect static type/assembly metadata using REA; record which conclusions are directly supported, not assumptions.
4. Compare *observed behavior* in the running demo against [the experiment matrix](havencraft-demo-evidence-2026-11-11.md): plot/work orders, input/output storage, task blockers, building brushes, world persistence.
5. Patch the independently written game systems with tests; do not copy recovered game code or assets into this repository.

## Notes on failed GitHub Actions probe
The [manual static reconnaissance workflow](../../.github/workflows/havencraft-demo-recon.yml) attempts official anonymous SteamCMD acquisition on a Windows-targeted Linux runner. It now runs only on explicit manual dispatch, because automatic retrying a known failure creates noise and bandwidth waste. It publishes a small sanitized failure artifact when acquisition fails. Neither a free price nor a public manifest ID proves anonymous SteamCMD entitlement.

- [REA CLI usage](https://github.com/morluto/rea/blob/main/docs/getting-started/cli.md)
- [REA desktop classification](https://github.com/morluto/rea/blob/main/docs/desktop-applications.md)
- [HavenCraft demo SteamDB metadata](https://steamdb.info/app/5260550/)
- [SteamRaw public app and save path configuration](https://steamraw.com/app/5260550/havencraft-demo/)
