@echo off
REM Instala as dependencias do tray_menu.
pushd "%~dp0"
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
popd
pause
