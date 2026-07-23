@echo off
GOTO EndComment
This script is designed to remove all traces of the Datto RMM tool from a Windows machine.
This script was crafted using information from the following sources:
Per - https://www.reddit.com/r/Datto/comments/12hqkny/silently_uninstall_datto_rmm_agent/
	- https://rmm.datto.com/help/en/Content/4WEBPORTAL/Devices/ServersLaptopsDesktops/Windows/InstallWindows.htm
	- https://stackoverflow.com/questions/11269338/how-to-comment-out-add-comment-in-a-batch-cmd
231018 - Joel Cottrell
:EndComment
taskkill /f /im gui.exe 2>nul
echo Waiting for Datto RMM to be removed...
"C:\Program Files (x86)\CentraStage\uninst.exe" /S 2>nul
powershell -ExecutionPolicy Bypass -Command "Start-Sleep -Seconds 10"
rmdir "C:\Program Files (x86)\CentraStage" /S /Q 2>nul
rmdir "C:\Windows\System32\config\systemprofile\AppData\Local\CentraStage" /S /Q 2>nul
rmdir "C:\Windows\SysWOW64\config\systemprofile\AppData\Local\CentraStage" /S /Q 2>nul
rmdir "%userprofile%\AppData\Local\CentraStage" /S /Q 2>nul
rmdir "%allusersprofile%\CentraStage" /S /Q 2>nul
REG delete "HKEY_CLASSES_ROOT\cag" /f 2>nul
REG delete "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run" /v CentraStage /f 2>nul
