@echo off
setlocal

set "BASE=C:\Desenvolvimento\Componentes"

if not exist "%BASE%\CEF4Delphi" exit /b 1

rem OLD -> NEW
if exist "%BASE%\CEF4Delphi-new" (
    ren "%BASE%\CEF4Delphi" "CEF4Delphi-temp" || exit /b 1
    ren "%BASE%\CEF4Delphi-new" "CEF4Delphi" || exit /b 1
    ren "%BASE%\CEF4Delphi-temp" "CEF4Delphi-lasted" || exit /b 1
    exit /b 0
)

rem NEW -> OLD
if exist "%BASE%\CEF4Delphi-lasted" (
    ren "%BASE%\CEF4Delphi" "CEF4Delphi-temp" || exit /b 1
    ren "%BASE%\CEF4Delphi-lasted" "CEF4Delphi" || exit /b 1
    ren "%BASE%\CEF4Delphi-temp" "CEF4Delphi-new" || exit /b 1
    exit /b 0
)

exit /b 1
