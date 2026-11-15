@echo off
setlocal

rem Ensure the Chinese PoB environment (same hard rule as pob-bd-builder).
rem Do not hard-fail here: a user may have launched Chinese PoB manually after
rem the start script's click was blocked by a launcher update prompt.
call "%USERPROFILE%\.dsh\skills\pob-bd-builder\scripts\start-cn.cmd" >nul

rem Do not `call` runtime.env: .env is not a batch file and Windows may
rem open an "open with" dialog for it. This CLI only needs a Python
rem interpreter, so use an inherited POB_PYTHON or PATH python instead.
if defined POB_PYTHON (
  set "PY=%POB_PYTHON%"
) else (
  set "PY=python"
)

"%PY%" "%~dp0planner_cli.py" %*
exit /b %errorlevel%
