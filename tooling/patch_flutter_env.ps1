$path = 'C:\flutter\bin\flutter.bat'
$backup = 'C:\flutter\bin\flutter.bat.bak_codex'

if (!(Test-Path $backup)) {
  Copy-Item $path $backup
}

$content = Get-Content $path -Raw
$needle = "SETLOCAL`r`n"
$insert = @"
SETLOCAL
SET PATHEXT=.COM;.EXE;.BAT;.CMD;.VBS;.VBE;.JS;.JSE;.WSF;.WSH;.MSC;.CPL
SET PATH=C:\Program Files\Git\cmd;C:\Windows\System32;C:\Windows;%PATH%
"@ + "`r`n"

if (-not $content.Contains('SET PATHEXT=.COM;.EXE;.BAT;.CMD;.VBS;.VBE;.JS;.JSE;.WSF;.WSH;.MSC;.CPL')) {
  $content = $content.Replace($needle, $insert)
  Set-Content -Path $path -Value $content -Encoding ascii
}
