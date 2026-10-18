@echo off
rem Run the headless checks. Exits nonzero if any of them fails.
set LOVE="C:\Program Files\LOVE\lovec.exe"
set GAME="%~dp0..\game"
for %%M in (--selftest --flow --slack) do (
  echo == %%M
  %LOVE% %GAME% %%M
  if errorlevel 1 (
    echo FAILED: %%M
    exit /b 1
  )
)
echo all checks passed
