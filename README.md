# SnowRunner Mods

Source files for my [SnowRunner mods on mod.io](https://mod.io/u/mrskladak).

All code and original assets in this repository are MIT licensed. SnowRunner/Saber game assets remain the property of their respective owners.

## Repository layout

Each top-level mod directory is a package source. Its `classes` directory must be at the root of the inner `.pak` archive; do not archive the mod directory itself.

`initial.pak` is game data used as a reference. Never commit it, redistribute it, or edit the installed copy in place.

## Current Epic Games paths

The paths found on this machine are:

- Game: `C:\Program Files\Epic Games\SnowRunner`
- Current data archive: `C:\Program Files\Epic Games\SnowRunner\en_us\preload\paks\client\initial.pak`
- User data: `C:\Users\jakub\Documents\My Games\SnowRunner\base`
- Local mod source: `C:\Users\jakub\Documents\My Games\SnowRunner\Media\Mods`
- Installed mod.io mods: `C:\Users\jakub\Documents\My Games\SnowRunner\base\Mods\.modio\mods`
- Logs: `C:\Users\jakub\Documents\My Games\SnowRunner\base\logs`

Install layouts can change by storefront, language, or game update. If the path differs, search the game installation recursively for `initial.pak`. In Epic Games Launcher, update/verify SnowRunner before extracting source XML; "latest" here means the XML in the currently installed game build.

## Refresh a vanilla XML after a game update

1. Close SnowRunner.
2. Verify/update it in Epic Games Launcher.
3. Copy `initial.pak` to a temporary working directory, or extract directly from it without modifying it.
4. Open the archive with 7-Zip or another ZIP-compatible archive reader. SnowRunner `.pak` files in this workflow are ZIP archives.
5. Extract the required file from `[media]/classes/...`. For the TwinSteer it is `[media]/classes/trucks/ws_6900xd_twin.xml`.
6. Copy it into the mod under `classes/trucks` with a unique filename.
7. Add `OriginalTruck="ws_6900xd_twin"` to the root `<Truck>` element so the mod creates a separate truck instead of replacing the vanilla class.
8. Reapply only the intended modifications. Compare against the previous mod XML rather than copying all old changes blindly.
9. Give the clone a distinct `UiName` so it can be identified in the Truck Store.

Example extraction of the complete archive to a temporary directory:

```powershell README.md
$pak = 'C:\Program Files\Epic Games\SnowRunner\en_us\preload\paks\client\initial.pak'
$temp = Join-Path $env:TEMP 'snowrunner-initial'
New-Item -ItemType Directory -Force $temp | Out-Null
tar -xf $pak -C $temp
Copy-Item "$temp\[media]\classes\trucks\ws_6900xd_twin.xml" `
  '.\twinsteer_plus_logs\classes\trucks\twinsteer_plus_logs.xml'
```

For `twinsteer_plus_logs`, preserve this socket from the JoAT TwinSteer:

```xml README.md
<AddonSockets>
    <Socket Names="JoatFrameAddon4" Offset="(-1.45; 1.47; 0)" ParentFrame="BoneChassis_cdt" />
</AddonSockets>
```

That socket is consumed by the long-log carrier in `log_addons`; it does not embed that mod's meshes or cargo definitions. Users must also enable [Double-Decker Multi-Load Log Addons, All Lengths](https://mod.io/g/snowrunner/m/double-decker-multi-load-log-addons-all-lengths) (mod.io ID `1655254`). Add it as a dependency on the new mod's mod.io page if dependency controls are available.

## TwinSteer fuel-tank assets and conversion diagnosis

`twinsteer_plus_logs` is not XML-only. The truck references vanilla assets, but its `[JoAT] Huge Fuel Tank` includes custom resources:

- `classes/trucks/addons/twinsteer_fuel.xml`: fuel capacity `4800`, installation socket `JoatFuelAddon4`;
- `meshes/trucks/tuning/quad_tank.fbx` and `quad_tank.xml`: tank mesh and material;
- `textures/trucks/quad_tank__d.tga`, `quad_tank__n_d.tga`, and `quad_tank__sh_d.tga`: albedo, normal, and shading textures.

The conversion cleanup retained the tank, capacity, and socket. Diffuse and shading textures were changed from 32-bit TGA to uncompressed 24-bit TGA by removing fully opaque alpha only; all RGB pixels, dimensions, orientation, and footer were preserved. The normal texture was already 24-bit and is unchanged. The material now uses `AlphaKill="false"` because the albedo has no transparency.

**This is a compatibility cleanup, not a confirmed crash fix.** Both original and cleaned textures passed standalone conversion with the installed resource converter. All three current textures are 1024x1024 and produce nonempty PC PCT output with exit code 0; all three XML fragments parse successfully. Standalone FBX conversion and local spawning/tank rendering were subsequently verified (see below). Full in-game Convert, Pack, and console builds remain unverified. Mixed cache timestamps suggested stale/partial resources, but did not prove the cause.

Original textures and the previous local workspace (including generated caches) were backed up outside the repository:

- `%LOCALAPPDATA%\SnowrunnerMods\texture-backups\20261017-190941`
- `%LOCALAPPDATA%\SnowrunnerMods\workspace-backups\20261017-191034\twinsteer_plus_logs`

The cleaned source was synced to the local mod workspace, removing previous generated caches. Repository and deployed source hashes match. No installed game files were changed.

To reproduce a standalone texture test from the repository root:

```powershell
$exe = 'C:\Program Files\Epic Games\SnowRunner\en_us\Sources\Bin\SnowrunnerResourceConverter.exe'
$root = (Resolve-Path '.\twinsteer_plus_logs').Path
$output = Join-Path $env:TEMP 'snowrunner-texture-validation'
New-Item -ItemType Directory -Force $output | Out-Null
Get-ChildItem "$root\textures\trucks\*.tga" | ForEach-Object {
    $pct = Join-Path $output ($_.BaseName + '.pct')
    Remove-Item -LiteralPath $pct -Force -ErrorAction SilentlyContinue
    & $exe --mod-convert --all-pct --singl-thread-pct-convert `
        --root-mod-path $root -r $root `
        -i ('textures/trucks/' + $_.Name) -o $pct
    if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $pct)) {
        throw "Texture conversion failed: $($_.Name)"
    }
    if ((Get-Item -LiteralPath $pct).Length -eq 0) {
        throw "Empty texture output: $($_.Name)"
    }
}
```

This command validates standalone PC texture output only; `--all-pct` does not establish that console conversion passed. It also does not validate the mesh or the entire mod.

[Official Saber texture requirements](https://expeditions-guides.saber.games/truck_modding/getting_started/simple_truck_mod_from_scratch/step_3_creating_textures/) still specify TGA and naming postfixes such as `__d`, `__d_a`, `__n_d`, and `__sh_d`. [Texture properties are defined in mesh XML](https://expeditions-guides.saber.games/truck_modding/general_info/fbx_file_structure/textures/). Research found no verified recent requirement invalidating these textures. A [June 2022 community report](https://steamcommunity.com/app/1465360/discussions/0/5260782129618875791/) describes update 17.0 breaking custom-texture map loading and a later patch restoring it; it is not evidence for this truck conversion crash. Some search sources were inaccessible, and no matching modern conversion-crash report was verified.

### Reproduced in-game converter crash

The in-game resource-conversion path crashes on both custom assets and Saber's untouched sample. Captured fuel-package mesh and official-sample texture dumps both show a null-address write (`0xC0000005`) inside `SnowrunnerResourceConverter.exe+0xADC811`. Texture jobs can generate output before failing, so this is not universally a startup failure. The fuel-package attempt failed once per source resource: 12 textures and four meshes.

Earlier replay of a game-generated command returned `-1` with `--backend-auth-params` and `0` without it. Backend/session handling remains a lead, not a proven root cause; session validity, crash-reporting options, and other launch differences have not been fully isolated. No session tokens are stored in this repository. The evidence does not justify blaming texture bit depth, geometry complexity, or a defective graphics card.

Use the standalone workaround with SnowRunner closed:

```powershell
.\Convert-SnowRunnerMod.ps1 twinsteer_plus_logs
```

The script stages source files, validates XML, converts TGA to DDS and PC PCT and FBX to the mesh cache using the installed converter without backend/session arguments, then deploys to the local mod workspace. It backs up the previous workspace under `Media\ModBackups` and leaves installed game files and source textures unchanged. All three DDS textures, PC PCT textures, and the fuel-tank mesh were successfully converted and deployed. Syncing source again removes these generated resources; rerun this script afterward.

**Verified local test:** after deployment of the revised cache, the user confirmed that `/twinsteer_plus_logs` appears in Create, the truck spawns, and `[JoAT] Huge Fuel Tank` installs, renders correctly, and shows **4800** capacity. Mod Manager still displays **Not converted**; that label did not prevent spawning in this test. The earlier claim that this status necessarily excluded the truck from Create was incorrect.

The revised script adds PC PCT caches and keeps both the resource-loader filenames and the observed in-game converter's `textures_`-prefixed filenames. The deployed workspace also contains unprefixed NX PCT caches; their origin and the minimal cache set required for spawning have not been isolated. This test verifies the current deployed workspace, not that a clean script-only deployment is sufficient. Full in-game Convert, refueling, collision/recovery/save behavior, the external long-log addon, Pack, and console builds remain unverified. No conversion-status marker is fabricated.

This is a local conversion workaround, not a console/platform packaging replacement. No matching mod-author texture-conversion thread confirming a changed requirement was verified; the official TGA naming requirements still apply.

## Verified workaround: standalone conversion, then in-game Pack

On this installation, **standalone conversion -> Mod Manager recognizes Converted -> in-game Pack succeeds** has been demonstrated with `saber_conversion_control`. The XML-only `support_crew_trailers` also packed successfully.

The official sample was generated using **Summer Proving Grounds > Tools > Add Mod**, with its source left unchanged. Standalone conversion passed for all 49 textures (DDS and PCT) and seven meshes: 105 converter invocations. The deployed 252 cache files included filename aliases and 49 NX texture caches. Mod Manager subsequently reported **Converted**, and the user successfully ran **Pack**. Both controls produced six platform ZIPs; each inspected ZIP contained the mod PAK and matching platform PAK. This verifies conversion recognition and outer package layout, not downloaded-build behavior, driving/rendering, console compatibility, or mod.io approval.

For a repository mod, close SnowRunner and run from the repository root:

```powershell
# Example: select the mod you intend to update.
.\Convert-SnowRunnerMod.ps1 -ModName fuel_cistern_skid_and_repair_rack
```

The script validates and converts source before deployment, backs up the old target under `Media\ModBackups`, then replaces that target workspace. It does not update other mods. Do not resync afterward: Sync replaces the workspace and can overwrite generated caches. Preserve any local-only changes before converting; the script uses the source beside itself, not the deployed source.

For an isolated test without changing the real local Mods folder:

```powershell
$testMedia = Join-Path $env:LOCALAPPDATA ('SnowrunnerMods\conversion-diagnostics\test-' + [guid]::NewGuid().ToString('N') + '\Media')
.\Convert-SnowRunnerMod.ps1 -ModName fuel_cistern_skid_and_repair_rack -SnowRunnerMedia $testMedia
```

`-SnowRunnerMedia` changes the destination, not the source. The script resolves `ModName` relative to its own directory (`$PSScriptRoot`). The game-generated Saber control is not repository source: for that test, the unchanged script was copied beside an isolated `saber_conversion_control` source folder, excluding old `prebuild` and `RebuildLog` folders. After conversion to an isolated Media directory, only successful generated caches were deployed, following a verified backup. Do not assume `.\Convert-SnowRunnerMod.ps1 saber_conversion_control` works from this repository without first preparing that source.

Next, launch the game, **Reload**, test with **Create**, and use **Mod Manager > Pack**. Do not click in-game **Convert** again on this affected installation merely to repeat work already completed standalone. If the status or Create behavior differs, inspect the logs rather than fabricating a conversion-status marker. The sample's successful status and Pack do not establish the same results for TwinSteer or every other mod.

The standalone script is not a release packer. `--all-pct` generates texture resources, including observed NX output; it does not establish complete console builds. Use the game's Pack step for genuine platform archives.

## Validate before packaging

SnowRunner class files are XML fragments with sibling `_templates` and class elements, so wrap each file in one temporary root element when using .NET's XML parser:

```powershell README.md
$mod = '.\twinsteer_plus_logs'
Get-ChildItem $mod -Recurse -Filter *.xml | ForEach-Object {
    try {
        $fragment = Get-Content -Raw $_.FullName
        [xml]("<snowrunner-validation-root>$fragment</snowrunner-validation-root>") | Out-Null
    }
    catch { throw "Invalid XML: $($_.FullName): $($_.Exception.Message)" }
}
```

Also check that:

- the archive source contains `classes` at its root;
- every cloned truck has a unique source filename and `OriginalTruck` value;
- mesh, texture, socket, suspension, engine, gearbox, and tuning names match current game data;
- the displayed name distinguishes the mod truck from vanilla;
- dependencies are documented and active;
- `git diff` contains no extracted game archive or temporary files.

## Test locally in Summer Proving Grounds

**Summer Proving Grounds** is built into SnowRunner's PC mod tools; it is not the separately downloadable `Polygon2` map. Local source mods belong under `%USERPROFILE%\Documents\My Games\SnowRunner\Media\Mods`, not under `base\Mods\.modio\mods` (that directory is managed by the Mod Browser).

For the affected installation, close SnowRunner and use the standalone conversion command in the verified workaround above. It also deploys the converted workspace, so a separate Sync is unnecessary.

For source-only deployment (not conversion), the repository also provides:

```powershell README.md
.\Sync-SnowRunnerMod.ps1 twinsteer_plus_logs
```

Sync replaces `...\Media\Mods\twinsteer_plus_logs` with the repository copy, including its cache state. Close the game first, preserve local-only changes, and rerun standalone conversion if you use Sync. Do not casually resync the working TwinSteer. If Documents is redirected or a different workspace is required, pass `-SnowRunnerMedia 'D:\path\to\SnowRunner\Media'`.

Then perform the supported workflow in SnowRunner:

1. Open **Mod Browser**, choose **More**, then **Select map**.
2. Select **Summer Proving Grounds**. The map opens with the **TOOLS** menu.
3. Click **Reload** so the copied mod is discovered.
4. Open **Mod Manager** and select the converted mod. With the workaround, do not click **Convert** again. The official sample reports **Converted**; TwinSteer's earlier **Not converted** label did not prevent its local spawning test.
5. Click **Reload** again. After source changes, close the game, rerun standalone conversion, then relaunch and **Reload**. On an installation where in-game conversion works normally, the standard **Convert**, then **Reload** workflow remains available.
6. Click **Create**. In **Spawn Truck**, select the truck under `/twinsteer_plus_logs/...`, place it on the map, click **Add**, then **Done**.
7. Install `[JoAT] Huge Fuel Tank` and verify its 4800 fuel capacity, placement, refueling, collisions, recovery, and save/reload behavior. Also test the required `1655254` long-log add-on, including installation and packing/unpacking.

If conversion or Pack crashes, stop repeated attempts and preserve the fresh `base\logs\LegacyLog.txt`, local converter/rebuild logs, and `%LOCALAPPDATA%\Saber\CrashDump.dmp` before another resource job overwrites the dump. Leave the first crash-report dialog open when capturing the failing process. Dumps may contain session data; do not commit or publicly upload them. Preserve evidence before resyncing. Identify whether texture, FBX/mesh, or platform conversion failed; successful standalone texture conversion is not proof that the full mod works.

If the mod does not appear, verify the path is exactly `...\Media\Mods\twinsteer_plus_logs\classes\trucks\twinsteer_plus_logs.xml`, then inspect `base\logs\LegacyLog.txt` for conversion or XML errors.

## Pack platform builds in SnowRunner

Use SnowRunner's **TOOLS** menu for release packages; this is the step that creates platform-specific resources:

1. Complete standalone conversion with the game closed, then open Summer Proving Grounds, **Reload**, and test the current source. Do not repeat the crashing in-game **Convert** step. This conversion-then-Pack workaround is verified for the Saber control; TwinSteer packing remains to be validated.
2. Open **Mod Manager**, select `twinsteer_plus_logs`, and click **Pack**.
3. Wait for validation and packing to complete. Errors are written to `base\logs\LegacyLog.txt`.
4. Find the generated archives in `Documents\My Games\SnowRunner\Media\Mods\<mod_name>`. The successful Saber and support-crew controls each produced:
   - `<mod_name>_pc.zip`
   - `<mod_name>_playstation_4.zip`
   - `<mod_name>_playstation_5.zip`
   - `<mod_name>_xbox_one.zip`
   - `<mod_name>_xbox_series.zip`
   - `<mod_name>_nintendo_switch2.zip`

   Each inspected ZIP already contains `<mod_name>.pak` and its matching platform PAK (for example, `pc.pak`). No original Nintendo Switch package was present in these runs. Older documentation lists `_nx64.zip`; do not assume it was generated, equate it with Switch 2, or rename another package to substitute for it. Available targets and filenames may change with game versions.
5. Upload each ZIP separately on the mod.io mod page and select only its matching platform. Do not combine all platform ZIPs into another archive.
6. Submit the console files for review, and test each approved version through that console's in-game Mod Browser.

The game-generated packages supersede `Pack-SnowRunnerMod.ps1` for release and console submission. That script remains useful only as a quick XML/archive-layout check; it does not perform SnowRunner resource conversion or create console-specific builds.

`twinsteer_plus_logs` references stock truck assets and includes custom fuel-tank FBX/TGA resources. Console acceptance is not automatic: validate those resources with the game's Pack workflow and confirm redistribution rights before publishing. Required mod `1655254` must also be approved and available on every target platform. Do not include extracted vanilla assets or modify `initial.pak`.


## Test through mod.io

Testing through a hidden mod.io listing is slower than replacing game files, but it exercises the same packaging and processing path used by players and avoids corrupting `initial.pak`.

1. Create a SnowRunner mod at [mod.io](https://mod.io/g/snowrunner) and keep it hidden while testing.
2. Upload the game-generated outer ZIP for the selected platform as a new mod file, set a version/changelog, and wait for processing. The verified ZIPs already contain the mod `.pak` and matching platform output such as `pc.pak` before upload; do not rely on mod.io to turn a source/layout-check archive into a platform release.
3. Subscribe to the hidden mod using the same mod.io account used in SnowRunner.
4. Subscribe to and activate mod `1655254` as well.
5. In SnowRunner, open **Mod Browser**, wait for downloads to finish, and enable both mods. Restart the game if the browser says changes require it.
6. Use a disposable or backed-up save. Buy **JoaT 6900 TwinSteer** from the Truck Store; do not test with the vanilla TwinSteer.
7. In customization, confirm the JoAT long-log addon appears, installs at the expected position, packs/unpacks logs, does not collide with the chassis, and survives garage/map transitions.
8. Also verify normal TwinSteer behavior: steering, suspension, AWD/diff lock, wheels, default visual addons, damage, winch points, sounds, cockpit, recovery, selling, and repurchasing.
9. Test single-player and multiplayer if the release claims multiplayer support.

If the mod does not load, inspect:

- `C:\Users\jakub\Documents\My Games\SnowRunner\base\logs\LegacyLog.txt`
- `C:\Users\jakub\Documents\My Games\SnowRunner\base\logs\BackendLog.txt`
- `C:\Users\jakub\Documents\My Games\SnowRunner\base\logs\ModMapError.txt`

Search for the mod filename, XML parse errors, unknown classes, missing meshes, and unresolved socket names. Disable the mod before replacing an uploaded test build, then re-enable it after the download completes.

## Deploy publicly

1. Commit and tag the exact source that passed the Proving Grounds test.
2. Convert that exact source standalone with SnowRunner closed, then launch the game, reload, test, and Pack. Use in-game Convert instead only if its failure has been resolved and verified.
3. Upload each generated platform ZIP separately with the matching platform selected and a useful version/changelog.
4. Confirm Windows processing succeeds and test the downloaded release once more.
5. Set the mod page/logo/summary/instructions/dependency, then make the listing public.
6. Verify dependency `1655254` is available on every console target, wait for console approval, and test each delivered build. Keep the mod XML-only or include only assets you have permission to redistribute.
7. After each SnowRunner update, verify the game in Epic, compare the latest vanilla XML with the mod, rerun conversion using the working route, reload, retest, and repack before publishing an update.

Useful references:

- [Saber: generate the official sample](https://expeditions-guides.saber.games/truck_modding/getting_started/sample_mod_by_the_game/creating_sample_mod/)
- [Saber: pack platform builds](https://expeditions-guides.saber.games/truck_modding/getting_started/sample_mod_by_the_game/packing_vehicle_mod/)
- [SnowRunner on mod.io](https://mod.io/g/snowrunner)
- [mod.io upload documentation](https://support.mod.io/hc/en-us/articles/360003012694-Uploading-a-mod)
- [This author's published mods](https://mod.io/u/mrskladak)
