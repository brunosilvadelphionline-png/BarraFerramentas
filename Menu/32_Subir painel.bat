@echo off
setlocal

set "PANEL_START=%~dp0..\..\PainelDeploy\start-panel.ps1"

if not exist "%PANEL_START%" (
    echo Script de inicializacao do painel nao encontrado:
    echo "%PANEL_START%"
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PANEL_START%"
set "PANEL_EXIT_CODE=%ERRORLEVEL%"

if not "%PANEL_EXIT_CODE%"=="0" (
    echo.
    echo Nao foi possivel iniciar o painel. Confira a mensagem acima.
    pause
)

exit /b %PANEL_EXIT_CODE%
