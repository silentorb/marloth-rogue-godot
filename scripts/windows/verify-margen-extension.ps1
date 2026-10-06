#Requires -Version 5.1
<#
.SYNOPSIS
  Windows-side margen GDExtension diagnostics (LoadLibrary matrix + MOTW).

.DESCRIPTION
  Run from the Windows project tree (e.g. E:\dev\games\marloth-godot\project):
    .\scripts\windows\verify-margen-extension.ps1

  Tests A-C simulate how Windows resolves margen_ffi.dll when Godot loads the
  extension DLL. Godot [dependencies] is export-oriented; runtime DLL search
  uses the executable directory first.
#>
param(
    [string]$PlayTree = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$GodotExe = $env:GODOT_BIN
)

if (-not ('MargenNativeLoad' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class MargenNativeLoad {
    [DllImport("kernel32", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr LoadLibrary(string path);

    [DllImport("kernel32", SetLastError = true)]
    public static extern bool FreeLibrary(IntPtr h);

    [DllImport("kernel32", SetLastError = true, CharSet = CharSet.Ansi)]
    public static extern IntPtr GetProcAddress(IntPtr h, string name);

    [DllImport("kernel32", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool SetDllDirectory(string path);

    public static string LastErrorMessage() {
        return new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error()).Message;
    }
}
'@ -Language CSharp
}

$ErrorActionPreference = "Stop"
$BinDir = Join-Path $PlayTree "addons\margen\bin"
$ExtDll = Join-Path $BinDir "libmargen_godot.windows.template_debug.x86_64.dll"
$FfiDll = Join-Path $BinDir "margen_ffi.dll"
$Gdext = Join-Path $PlayTree "addons\margen\margen.gdextension"
$ExtList = Join-Path $PlayTree ".godot\extension_list.cfg"
$EntrySymbol = "margen_godot_library_init"

function Write-Result([string]$Level, [string]$Message) {
    Write-Host ("{0}: {1}" -f $Level, $Message)
}

Write-Host "margen Windows extension probe"
Write-Host "PlayTree=$PlayTree"
Write-Host "============================================================="

if (-not (Test-Path $Gdext)) { Write-Result "FAIL" "missing $Gdext"; exit 1 } else { Write-Result "PASS" "margen.gdextension present" }
if (-not (Test-Path $ExtDll)) { Write-Result "FAIL" "missing $ExtDll"; exit 1 } else { Write-Result "PASS" "extension DLL present" }
if (-not (Test-Path $FfiDll)) { Write-Result "FAIL" "missing $FfiDll"; exit 1 } else { Write-Result "PASS" "margen_ffi.dll present" }

if (Test-Path $ExtList) {
    $listed = Select-String -Path $ExtList -Pattern "res://addons/margen/margen.gdextension" -SimpleMatch -Quiet
    if ($listed) { Write-Result "PASS" "extension_list.cfg lists margen.gdextension" }
    else { Write-Result "WARN" "extension_list.cfg present but does not list margen.gdextension" }
} else {
    Write-Result "WARN" ".godot/extension_list.cfg missing (CLI-first fresh tree)"
}

foreach ($path in @($ExtDll, $FfiDll)) {
    try {
        $zone = Get-Item $path -Stream Zone.Identifier -ErrorAction SilentlyContinue
        if ($null -ne $zone) {
            Write-Result "WARN" "MOTW Zone.Identifier present on $path - Unblock-File if load fails"
        } else {
            Write-Result "PASS" "no Zone.Identifier on $(Split-Path $path -Leaf)"
        }
    } catch {
        Write-Result "PASS" "no Zone.Identifier on $(Split-Path $path -Leaf)"
    }
}

function Test-Load([string]$Name, [scriptblock]$Setup, [scriptblock]$Teardown) {
    & $Setup
    try {
        $h = [MargenNativeLoad]::LoadLibrary($ExtDll)
        if ($h -eq [IntPtr]::Zero) {
            Write-Result "FAIL" "$Name - LoadLibrary failed: $([MargenNativeLoad]::LastErrorMessage())"
            return $false
        }
        $proc = [MargenNativeLoad]::GetProcAddress($h, $EntrySymbol)
        if ($proc -eq [IntPtr]::Zero) {
            Write-Result "FAIL" "$Name - GetProcAddress($EntrySymbol) failed: $([MargenNativeLoad]::LastErrorMessage())"
            [MargenNativeLoad]::FreeLibrary($h) | Out-Null
            return $false
        }
        Write-Result "PASS" "$Name - LoadLibrary + $EntrySymbol OK"
        [MargenNativeLoad]::FreeLibrary($h) | Out-Null
        return $true
    } catch {
        Write-Result "FAIL" "$Name - exception: $($_.Exception.Message)"
        return $false
    } finally {
        & $Teardown
    }
}

Write-Host "LoadLibrary matrix"
Write-Host "-------------------------------------------------------------"

Test-Load "A (no FFI preload, no SetDllDirectory)" {
    [MargenNativeLoad]::SetDllDirectory([NullString]::Value) | Out-Null
} {
    [MargenNativeLoad]::SetDllDirectory([NullString]::Value) | Out-Null
} | Out-Null

Test-Load "B (SetDllDirectory -> addons/margen/bin)" {
    [MargenNativeLoad]::SetDllDirectory($BinDir) | Out-Null
} {
    [MargenNativeLoad]::SetDllDirectory([NullString]::Value) | Out-Null
} | Out-Null

$script:ffiHandle = [IntPtr]::Zero
Test-Load "C (preload margen_ffi.dll then extension)" {
    $script:ffiHandle = [MargenNativeLoad]::LoadLibrary($FfiDll)
    if ($script:ffiHandle -eq [IntPtr]::Zero) {
        Write-Result "FAIL" "C - could not preload margen_ffi.dll: $([MargenNativeLoad]::LastErrorMessage())"
    }
} {
    if ($script:ffiHandle -ne [IntPtr]::Zero) {
        [MargenNativeLoad]::FreeLibrary($script:ffiHandle) | Out-Null
        $script:ffiHandle = [IntPtr]::Zero
    }
} | Out-Null

Write-Result "INFO" "D (copy margen_ffi.dll next to Godot.exe) is a manual experiment - not automated here"

Write-Host "============================================================="
Write-Host "Godot probe commands (capture full --verbose log):"
if ([string]::IsNullOrWhiteSpace($GodotExe)) {
    $GodotExe = 'E:\Programs\godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64_console.exe'
}
Write-Host ('  & "{0}" --path "{1}" --verbose --script res://scripts/margen_extension_probe.gd 2>&1 | Tee-Object margen-godot.log' -f $GodotExe, $PlayTree)
Write-Host ('  & "{0}" --path "{1}" --editor --verbose --script res://scripts/margen_extension_probe.gd 2>&1 | Tee-Object margen-godot-editor.log' -f $GodotExe, $PlayTree)
Write-Host "Grep log for: Can't open GDExtension, Error loading extension, margen_godot: library_init, margen_godot: initialized"
Write-Host "If Linux functional tests PASS but this fails, paste the report + log."
