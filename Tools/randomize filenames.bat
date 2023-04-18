@echo off
setlocal EnableDelayedExpansion
for %%F in ("*.wav") do (
    ren "%%~F" "explosion-!RANDOM!.wav"
)
endlocal
pause