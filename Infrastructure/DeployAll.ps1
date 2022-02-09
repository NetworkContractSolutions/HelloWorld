function Get-ScriptDirectory {
    $directorypath = if ($PSScriptRoot) { $PSScriptRoot } `
        elseif ($psise) { split-path $psise.CurrentFile.FullPath } `
        elseif ($psEditor) { split-path $psEditor.GetEditorContext().CurrentFile.Path }
    return $directorypath
}

Clear-Host
$path = Get-ScriptDirectory
Set-Location $path

# Run these scripts at least once (can be ran each time).
Push-Location .\OneTimeScripts
Start-Process PowerShell -Wait -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$pwd'; & '.\DeploySelfSigned.ps1';`""
Start-Process PowerShell -Wait "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$pwd'; & '.\DeployNginx.ps1';`""
Pop-Location

Push-Location ../HelloWorld/Infrastructure
./Deploy.ps1
Pop-Location