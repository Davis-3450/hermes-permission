# Fix-HermesPermissions.ps1

A comprehensive PowerShell remediation utility designed to diagnose and resolve **permission corruptions, privilege bleed, broken NTFS inheritance, and Win32 process custody locks** across local installations of [Hermes Agent](https://github.com/nousresearch/hermes-agent) on Windows (`%LOCALAPPDATA%\hermes`).

---

## Background & Problem Statement

Hermes Agent is a hybrid system combining:
- A core Python runtime and CLI (`agent/`, `hermes_cli/`).
- Frontend applications (React TUI, Electron Desktop app, Vite/Tauri bootstrap installer).
- Low-level Windows OS integrations (Job Object management via `kernel32.dll`, Win32 subprocess custody, and a privileged Computer-Use / CUA driver).

On Windows, installations frequently encounter persistent `[WinError 5] Access is denied` or command-launcher execution failures (`CLI exposure failed`, `source launcher publication failed`). These arise from four architectural issues:

### 1. Privilege Bleed via CUA Driver Escalation
When Hermes detects that the Computer-Use driver requires registration, it prompts:
```text
→ Windows cua-driver refresh deferred (autostart registration requires UAC).
