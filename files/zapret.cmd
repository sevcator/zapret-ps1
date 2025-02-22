@echo off
title Zapret Control
setlocal EnableDelayedExpansion
set "zapretDir=%windir%\Zapret"
NET SESSION >nul 2>&1
if %errorLevel% neq 0 (
echo * Administrator rights required!
goto exit
)
:menu
cls
echo.
echo  /ZZZZZ    AAAA   PPPPP   RRRRR   EEEEE   TTTTT
echo      /Z   A    A  P    P  R    R  E         T
echo     /Z   A      A P    P  R    R  E         T
echo    /Z    AAAAAAAA PPPPP   RRRRR   EEEE      T
echo   /Z     A      A P       R   R   E         T
echo  /Z      A      A P       R    R  E         T
echo /ZZZZZ   A      A P       R     R EEEEE     T
echo    sevcator.github.io - github.com/bol-van
echo.
echo 1. Start service
echo 2. Stop service
echo 3. Restart service
echo 4. Change tactic
echo 5. Uninstall
echo 6. Exit
echo.
set /p choice="- Choice: "
if "%choice%"=="1" goto startService
if "%choice%"=="2" goto stopService
if "%choice%"=="3" goto restartService
if "%choice%"=="4" goto changeTactic
if "%choice%"=="5" goto uninstall
if "%choice%"=="6" goto exit
goto menu

:startService
cls
echo.
net start winws1 >nul 2>&1
echo - Service has been started!
timeout /t 2 /nobreak >nul 2>&1
goto menu

:stopService
cls
echo.
net stop winws1 >nul 2>&1
sc stop windivert >nul 2>&1
sc stop windivert11 >nul 2>&1
echo - Service has been stopped!
timeout /t 2 /nobreak >nul 2>&1
goto menu

:restartService
cls
echo.
net stop winws1 >nul 2>&1
sc stop windivert >nul 2>&1
sc stop windivert11 >nul 2>&1
timeout /t 1 /nobreak >nul 2>&1
net start winws1 >nul 2>&1
echo - Service has been restarted!
timeout /t 2 /nobreak >nul 2>&1
goto menu

:changeTactic
cls
echo.
echo - Available tactics:
echo.
for %%F in ("%zapretDir%\tactics\*.txt") do (
echo %%~nF
)
echo.
set /p tactic="- Tactic: "
if not exist "%zapretDir%\tactics\%tactic%.txt" (
echo * Tactic not found!
timeout /t 2 /nobreak >nul 2>&1
goto menu
)
for /f "delims=" %%i in ('type "%zapretDir%\tactics\%tactic%.txt"') do set "tacticContent=%%i"
set "tacticContent=!tacticContent:%%zapretDir%%=%zapretDir%!"
set "tacticContent=!tacticContent:%%DIR_ARGS%%=%zapretDir%!"
sc stop winws1 >nul 2>&1
timeout /t 1 /nobreak >nul 2>&1
sc delete winws1 >nul 2>&1
timeout /t 1 /nobreak >nul 2>&1
sc create winws1 binPath="%zapretDir%\winws.exe !tacticContent!" start=auto DisplayName="zapret" type=own >nul 2>&1
sc description winws1 "Bypass internet censorship via modification DPI @ by bol-van & sevcator.github.io" >nul 2>&1
net start winws1 >nul 2>&1
echo - Tactic changed successfully!
timeout /t 2 /nobreak >nul 2>&1
goto menu

:uninstall
cls
echo.
set /p confirm="- [Y/N] Are you want to uninstall? "
if /i not "%confirm%"=="Y" goto menu
set /p savetxt="- [Y] Save automatic hosts? "
if /i "%savetxt%"=="y" (
    if exist "%zapretDir%\list-auto.txt" (
        mkdir "%zapretDir%_temp" >nul 2>&1
        copy "%zapretDir%\list-auto.txt" "%zapretDir%_temp\" >nul 2>&1
        rmdir /s /q "%zapretDir%" >nul 2>&1
        rename "%zapretDir%_temp" "Zapret" >nul 2>&1
    )
) else (
    rmdir /s /q "%zapretDir%" >nul 2>&1
)
net stop winws1 >nul 2>&1
sc stop windivert >nul 2>&1
sc stop windivert11 >nul 2>&1
timeout /t 1 /nobreak >nul 2>&1
sc delete winws1 >nul 2>&1
rmdir /s /q "%zapretDir%" >nul 2>&1
del "%windir%\System32\zapret.cmd" >nul 2>&1
echo - Uninstalled
timeout /t 2 /nobreak >nul 2>&1
goto exit

:exit
