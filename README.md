# WorkLock

Closes your games until your work is done.

WorkLock runs quietly in the background on Windows. About once a minute it checks for games,
and if today's work isn't finished, it closes them and shows what's left to do. Tick everything
off and games unlock for the rest of the day.

## Install

1. Download this repo (**Code → Download ZIP**) and unzip it.
2. Right-click `install.ps1` → **Run with PowerShell**.

No admin rights needed. It installs to `%LOCALAPPDATA%\WorkLock`, starts now, starts again every
time you log in, and puts a **WorkLock Tasks** shortcut on your desktop.

If Windows blocks the script, open PowerShell in the folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

## Using it

Open **WorkLock Tasks** from the desktop.

- **Add** today's work. Tick **Weekly** for things that come back every Monday (like weekly homework).
- **Tick** each task when it's done. When everything is ticked, games unlock.
- Games are locked until you've added a list for the day. If you really have nothing,
  press **No work today**.
- A new day starts at 4am. Anything unfinished carries over to the next day.

### Get someone to keep you honest (PIN)

Press **PIN...** and have a parent or friend type a PIN. After that, ticking tasks off,
removing unfinished tasks and "No work today" all need the PIN. So you have to show them your work
before games unlock. Adding tasks never needs the PIN.

## What counts as a game

Minecraft (Lunar, Modrinth, CurseForge, Prism, TLauncher, Badlion, the official launcher, and any
Minecraft Java process), Steam and every Steam game, Epic, Battle.net, Riot/Valorant/League, Roblox,
EA, Ubisoft, GOG, Xbox app games, and a few more.

To add one, open `%LOCALAPPDATA%\WorkLock\config.json` and add the process name (as shown in
Task Manager's **Details** tab, without `.exe`) to `GameProcesses`. It's picked up at the next check.

| Setting | Default | What it does |
|---|---|---|
| `CheckSeconds` | `60` | How often it checks for games |
| `ResetHour` | `4` | When a new day starts (4 = 4am) |
| `GameProcesses` | see file | Process names to close |
| `GamePaths` | see file | Close anything running from these folders (`?` matches `\`) |

## Uninstall

Run `uninstall.ps1` from `%LOCALAPPDATA%\WorkLock`.

## Limits

It's a self-control tool, not parental-control software. Anyone who knows how can end it in Task
Manager or uninstall it, and it doesn't block browser games. A game can run for up to a minute before
the next check closes it.

Your task list is stored only on your PC, in `%LOCALAPPDATA%\WorkLock\data`.
