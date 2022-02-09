function Get-ScriptDirectory {
    $directorypath = if ($PSScriptRoot) { $PSScriptRoot } `
        elseif ($psise) { split-path $psise.CurrentFile.FullPath } `
        elseif ($psEditor) { split-path $psEditor.GetEditorContext().CurrentFile.Path }
    return $directorypath
}

Clear-Host
$path = Get-ScriptDirectory
Set-Location $path

Push-Location ../HelloWorld/Infrastructure
./Teardown.ps1
Pop-Location

Push-Location .\OneTimeScripts
& .\TeardownNginx.ps1
Pop-Location