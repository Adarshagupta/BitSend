@echo off
setlocal
set "PATHEXT=.COM;.EXE;.BAT;.CMD;.VBS;.VBE;.JS;.JSE;.WSF;.WSH;.MSC;.CPL"
set "PATH=C:\Users\adasg\OneDrive\Pictures\bitsend\tooling;C:\Program Files\Git\cmd;C:\Windows\System32;C:\Windows;C:\flutter\bin;%PATH%"
echo ===== %DATE% %TIME% =====> tooling\run_flutter_trace.log
echo ARGS: %*>> tooling\run_flutter_trace.log
echo PATH: %PATH%>> tooling\run_flutter_trace.log
echo PATHEXT: %PATHEXT%>> tooling\run_flutter_trace.log
where where >> tooling\run_flutter_trace.log 2>&1
where git >> tooling\run_flutter_trace.log 2>&1
where flutter >> tooling\run_flutter_trace.log 2>&1
call C:\flutter\bin\flutter.bat %*
echo EXITCODE: %ERRORLEVEL%>> tooling\run_flutter_trace.log
