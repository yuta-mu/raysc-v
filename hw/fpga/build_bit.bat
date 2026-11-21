@echo off
setlocal EnableDelayedExpansion

if "%~2"=="" (
    echo Usage: %~nx0 ^<config^> ^<hex_path^> [clk_div=16]
    echo   Configs: RV32I RV32I_MulOnly RV32IM_base RV32IM_zerostall RV32IM_pipemul RV32IM_Zbb_base RV32IM_Zbb_zerostall RV32IM_Zbb RV32IM_Zbb_Rand_base RV32IM_Zbb_Rand RV32IM_Zbb_QmulSqrt RV32IM_Zbb_MathOnly RV32IM_Zbb_C0_base RV32IM_Zbb_C0_zerostall RV32IM_Zbb_C0 RV32IM_Zbb_C0_nostall RV32IM_Zbb_Rand_Accel full full_nostall full_zerostall RV32IM_Zbb_C0_Accel
    echo   Example: %~nx0 RV32IM_Zbb_C0_Accel build\programs\raytracer\main_ar.hex 16
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..") do set "REPO_ROOT=%%~fI"

call :find_vivado
if errorlevel 1 exit /b 1

set "CFG=%~1"
for %%F in ("%~2") do set "HEX_PATH=%%~fF"
set "CLK_DIV=%~3"
if "%CLK_DIV%"=="" set "CLK_DIV=16"

pushd "%REPO_ROOT%"
if not exist "build\vivado_bit" mkdir "build\vivado_bit"

echo [RaySC-V] Building bitstream (config=%CFG%, hex=%HEX_PATH%, clk_div=%CLK_DIV%)
call "%VIVADO_CMD%" -mode batch -log "build\vivado_bit\vivado.log" -journal "build\vivado_bit\vivado.jou" -source "hw\fpga\build_bit.tcl" -tclargs "%CFG%" "%HEX_PATH%" "%CLK_DIV%"
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
