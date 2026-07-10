@echo off
setlocal

set "RESOLVER=C:\Desenvolvimento\Utilitarios\ResolucaoTarefas\ResolverTarefa.bat"
set "CODIGO="

set /p "CODIGO=Informe o codigo da tarefa: "
if not defined CODIGO exit /b 0

set "CODIGO=%CODIGO: =%"

if not defined CODIGO exit /b 0

if not exist "%RESOLVER%" (
    echo ResolverTarefa.bat nao encontrado: %RESOLVER%
    exit /b 1
)

call "%RESOLVER%" "%CODIGO%"
exit /b %ERRORLEVEL%
