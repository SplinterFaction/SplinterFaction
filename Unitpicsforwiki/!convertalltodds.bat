@echo off
REM Convert all PNG files in this folder to DDS using nvcompress
REM Requires nvcompress.exe in the same folder or in PATH

for %%f in (*.png) do (
    echo Converting %%f to %%~nf.dds
    "C:\Program Files\NVIDIA Corporation\NVIDIA Texture Tools\nvcompress.exe" -bc3 "%%f" "%%~nf.dds"
)
echo All conversions complete!
pause
