# 🌐 Dynamic PowerShell Profile Loader

![PowerShell](https://img.shields.io/badge/PowerShell-Profile-blue?logo=powershell&logoColor=white)
![Auto-Update](https://img.shields.io/badge/Auto--Synced-from%20GitHub-brightgreen)
![Maintained](https://img.shields.io/badge/Maintained-Yes-blue)

This PowerShell profile script automatically fetches and loads a **centralized PowerShell profile** from GitHub every time a new session starts. It allows you to centrally manage and update your PowerShell environment across multiple machines by simply updating the profile in your GitHub repo.

---

## 📄 Purpose

- ✅ Load a **remote PowerShell profile** dynamically from GitHub  
- 🔄 Keep your environment **up-to-date** with the latest changes  
- 💥 Eliminate the need to manually sync or copy profile scripts  
- 🛠 Gracefully handle errors if the remote script is unavailable

---

## 🧠 How It Works

This script:
1. Defines a GitHub URL pointing to your remote `Microsoft.PowerShell_profile.ps1`.
2. Downloads the file to the local temp directory.
3. Executes the script in the current PowerShell session.
4. Prints success or failure messages accordingly.

---

## 🔧 GitHub Source Reference

```powershell
$remoteProfile = 'https://raw.githubusercontent.com/bigjoestretch/powershell-toolkit/main/Shared/PowerShell-Profile/Microsoft.PowerShell_profile.ps1'
```

> 🔁 Update this URL if you move or rename your GitHub repo.

---

## 🛡️ Failsafe Behavior

If the remote script fails to load (e.g., due to no internet), the session will continue without breaking, and a warning will be shown:

```powershell
Write-Warning "⚠ Failed to load remote profile: $_"
```

---

## ✨ Benefits

- Central management of PowerShell profiles
- Easy rollout of changes to all systems
- Ideal for teams, enterprise admins, or multi-device users

---

## 📫 Author

**bigjoestretch**  
🔗 GitHub: [https://github.com/bigjoestretch](https://github.com/bigjoestretch)

---

> 💡 _"Centralized. Simplified. Automated."_  
