if not defined in_subprocess (cmd /k set in_subprocess=y ^& %0 %*) & exit 
setlocal enabledelayedexpansion
@echo off
REM ##############################################################################
REM SIMPLE CUBBIT MONITOR
REM ##############################################################################
REM # Author:           Mathias Koch / AdpOptimize
REM # Copyright:        (c)2021, Cubbit Monitor by MK
REM # License:          GPL
REM # Version:          1.0
REM # Maintainer:       Mathias Koch
REM # Email:            cubbit-monitor@adoptimize.de
REM # Status:           Production
REM # Roadmap:          check performance (CPU + RAM) and renice
REM # Credits:          To Famo my German-Shepherd and my true LOVE!
REM ##############################################################################
REM # this script will monitor cubbit. If too many upload errors will appear 
REM # in the log, Cubbit will be stopped and restarted. 
REM # If you have many files and some GB to be transfered to the swarm this 
REM # script will save your day
REM #
REM # if you have a standard installation, there should be nothing else to do 
REM # than just run the script an lay back
REM # ############################################################################
REM # ############################################################################


REM # Standard installation folder for the Cubbit executable
set "CubbitEx=C:\Program Files\Cubbit\Cubbit.exe";

REM # We use a linux tool to find the errors. Neccesarry cause Standard-Win apps 
REM # are too memory and cpu inefficient
set tailPath="%~dp0\usr\bin\tail.exe"
set tailLog="%~dp0\log\tailoutput.txt"

REM # init error counter
set /a totalErrorCount=0
set /a totalSuccessCount=0

REM # Stopp the running cubbit process. 
REM # @TODO check if running and find the current running log
call :cubbit_stop

REM # start a endless loop
REM # @TODO at the end this is not really needed cause after cubbit_performance
REM # a simple call for cubbit_running would be enough to keep the endless run
:loop
    TIMEOUT 60 
    call :cubbit_running
    call :cubbit_performance
goto :loop



REM -----------------------------------------------------------------------------
REM check the status and performance of cubbit
REM if there is no upload in the last 100 lines of code
REM and the init of the filesystem is over and errors are mentioned in the 
REM log. We inspect the frequency of 'errors' in subject to 'uploads'
REM if there are more than five errors we start to check the upload successes
REM and take in account wether we have more pos. or neg. and if so we restart 
REM cubbit 
REM -----------------------------------------------------------------------------
:cubbit_performance
    echo "tailing logfile !logfile! tail: !tailPath! -100 !logfile!"
    !tailPath! -100 !logfile! > !tailLog!
    set /a countUpload=1
	set /a countError=1

	for /f %%i in ('findstr /i /c:"Upload started" !tailLog!') do (
  	    set /a countUpload=countUpload+ 1

        if !totalErrorCount! EQU 2 (
            set /a countUpload=2
        )

        if !totalErrorCount! GTR 1 (
  	        set /a totalSuccessCount=countUpload+ 1
        )
	)

	for /f %%i in ('findstr /i /c:"This error originated either" !tailLog!') do (
  	    set /a countError=countError+ 1
	)

	if %countUpload% GEQ %countError% (
		echo "UploadCount: %countUpload% is greater or equal to " 
        echo "ErrorCount: %countError% all fine. Nothing to do."
	) else (
		echo "%countUpload% is smaller %countError% so we restart "
        set /a totalErrorCount=totalErrorCount+ 1
        echo "the total errors logged: !totalErrorCount!"
        echo "the total success logged: !totalSuccessCount!"

        if !totalErrorCount! GTR 5 (
            if !totalErrorCount! LSS !totalSuccessCount!  (
                set /a totalErrorCount=0
            )
        )  
        
       
        if !totalErrorCount! GTR 10 (
            set /a totalErrorCount=0
            set /a totalSuccessCount=0
            set /a countUpload=0
            goto :cubbit_stop
            TIMEOUT 10
            goto :cubbit_start
        )

	)
    REM goto :loop
EXIT/b

REM -----------------------------------------------------------------------------
REM check wether cubbit is running and if not restarts cubbit 
:cubbit_running
    echo "check if cubbit is running"
    tasklist /FI "IMAGENAME eq Cubbit.exe" 2>NUL | find /I /N "Cubbit.exe">NUL  

    if "%ERRORLEVEL%"=="0"  (
        echo "Cubbit is running, nothing to do"
    ) else (
        echo "Cubbit is NOT running. START Cubbit"
        goto :cubbit_start
    )
EXIT/b



REM -----------------------------------------------------------------------------
REM stop cubbit .. better KILL!
:cubbit_stop
    taskkill /f /im "Cubbit.exe"
    echo restart wait
    TIMEOUT 5 
EXIT/b

REM -----------------------------------------------------------------------------
REM start cubbit with a new logfile and delete the old log
:cubbit_start
    set datetime=%date:~-4%_%date:~3,2%_%date:~0,2%__%time:~0,2%_%time:~3,2%_%time:~6,2%
    set logfile="%~dp0\log\cubbit-action.!datetime!.log"
    echo "starting cubbit"
    START /B "cubbitRun" "!CubbitEx!" > !logfile!
    TIMEOUT 5
    echo "Cubbit is started"
EXIT/b 0



