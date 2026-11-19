@echo off
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..") do set "REPO_ROOT=%%~fI"

call :find_vivado
if errorlevel 1 exit /b 1

if "%~1"=="" (
    set "BIT_PATH=build\vivado_bit\latest.bit"
) else (
    for %%F in ("%~1") do set "BIT_PATH=%%~fF"
)

pushd "%REPO_ROOT%"
if not exist "build\vivado_bit" mkdir "build\vivado_bit"

echo [RaySC-V] Programming FPGA with %BIT_PATH%
call "%VIVADO_CMD%" -mode batch -log "build\vivado_bit\program.log" -journal "build\vivado_bit\program.jou" -source "hw\fpga\program_fpga.tcl" -tclargs "%BIT_PATH%"
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%

:find_vivado
set "VIVADO_CMD="
if defined VIVADO_BIN (
    if exist "%VIVADO_BIN%" set "VIVADO_CMD=%VIVADO_BIN%"
)
if not defined VIVADO_CMD (
    for /f "delims=" %%I in ('where vivado.bat 2^>nul') do (
        if not defined VIVADO_CMD set "VIVADO_CMD=%%I"
    )
)
if not defined VIVADO_CMD (
    for /d %%D in ("C:\Xilinx\Vivado\*") do (
        if exist "%%~fD\bin\vivado.bat" set "VIVADO_CMD=%%~fD\bin\vivado.bat"
    )
)
if not defined VIVADO_CMD (
    for /d %%D in ("C:\AMDDesignTools\*") do (
        if exist "%%~fD\Vivado\bin\vivado.bat" set "VIVADO_CMD=%%~fD\Vivado\bin\vivado.bat"
    )
)
if not defined VIVADO_CMD (
    echo [ERROR] Vivado not found. Add Vivado\bin to PATH or set VIVADO_BIN=C:\path\to\vivado.bat
    exit /b 1
)
exit /b 0
