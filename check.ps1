# Warning + test gate. Run after every feature: .\check.ps1
# Exit 0 = clean. Anything else = broken; read the output, don't trust the
# printed summary (gdUnit4 prints "PASSED" in its Statistics line even when a
# test failed -- the exit code is the only truth).
# Run one suite only: .\check.ps1 tests/entities/cabbage/cabbage_test.gd
# Compile + warnings only, no tests: .\check.ps1 -WarningsOnly
# Update $Godot when we move to 4.8.
param([string]$Only = "tests", [switch]$WarningsOnly)
$Godot = "C:\Users\wladi\Desktop\Godot_v4.7.2-stable_win64.exe"

Set-Location $PSScriptRoot

# GDScript warnings only reach stdout while a debugger is attached (-d). The script
# reloads every project script; any WARNING whose "at:" is our code fails the check.
# A script that fails to parse drops -d into the debug> prompt, which re-breaks forever
# on empty stdin; the first "Debugger Break" kills the process we started and fails.
# $w.Handle is read so ExitCode survives the process exiting without -Wait.
$warnLog = Join-Path $env:TEMP "project_cabbage_warnings.log"
$noInput = Join-Path $env:TEMP "project_cabbage_no_input.txt"
New-Item -ItemType File -Force $noInput | Out-Null
$warnArgs = @(
    "--headless", "--path", $PSScriptRoot, "-d", "--log-file", $warnLog,
    "-s", "tests/warning_check.gd"
)
$w = Start-Process -FilePath $Godot -ArgumentList $warnArgs -NoNewWindow -PassThru `
    -RedirectStandardInput $noInput -RedirectStandardOutput "$warnLog.out"
$null = $w.Handle
while (!$w.WaitForExit(250)) {
    if (Select-String -Path "$warnLog.out" -Pattern "Debugger Break" -Quiet) {
        Stop-Process -Id $w.Id -Force
        $w.WaitForExit()
        Write-Output "Script error stopped the warning check:"
        Select-String -Path "$warnLog.out" -Pattern "^Debugger Break, Reason: (.*)|^\*Frame 0 - (.*)" |
            ForEach-Object { "  " + ($_.Matches[0].Groups[1..2] | Where-Object Success).Value } |
            Select-Object -Unique -First 20
        exit 2
    }
}
if ($w.ExitCode -ne 0) { Write-Output "Warning check did not run (exit $($w.ExitCode))"; exit 2 }
$lines = @(Get-Content $warnLog)
$warnings = @()
for ($i = 0; $i -lt $lines.Count - 1; $i++) {
    if ($lines[$i] -like "WARNING:*" -and $lines[$i + 1] -match "\((res://[^)]+)\)") {
        $at = $Matches[1]
        if ($at -notlike "res://addons/*") {
            $warnings += "$at  $($lines[$i].Substring(9))"
        }
    }
}
if ($warnings.Count -gt 0) {
    Write-Output "GDScript warnings in our code:"
    $warnings | Sort-Object -Unique | ForEach-Object { Write-Output "  $_" }
    exit 2
}
if ($WarningsOnly) { Write-Output "No warnings."; exit 0 }

# Start-Process, not '&': the Godot exe is a GUI-subsystem binary, so PowerShell does
# not wait on it and $LASTEXITCODE stays 0 even when tests fail.
# --ignoreHeadlessMode: gdUnit4 aborts headless (103) because InputEvents don't
# fire there. Our tests never use input, so the check is irrelevant.
$godotArgs = @(
    "--headless", "--path", $PSScriptRoot,
    "-s", "addons/gdUnit4/bin/GdUnitCmdTool.gd",
    "--add", $Only, "--continue", "--ignoreHeadlessMode"
)
$p = Start-Process -FilePath $Godot -ArgumentList $godotArgs -NoNewWindow -Wait -PassThru
exit $p.ExitCode
