# rsync-transfer — Agent vs Manual Mode

This script has **two ways to use it**. Pick whichever fits your workflow.

---

## Cloud storage paths reference

When backing up to/from cloud drives, these are the standard locations on macOS:

| Service | Path pattern | Notes |
|---|---|---|
| **Google Drive** | `~/Library/CloudStorage/GoogleDrive-<email>/My Drive/` | Multiple profiles possible — one folder per email |
| **iCloud Drive** | `~/Library/Mobile Documents/com~apple~CloudDocs/` | Single iCloud account per machine |
| **Downloads** | `~/Downloads/` | Local — included for reference |

### ⚠️ Agent must verify before using

Do NOT assume these paths exist. Always check first:

```bash
# Find available Google Drive profiles
ls -1d ~/Library/CloudStorage/GoogleDrive-*

# Check iCloud Drive
ls -d ~/Library/Mobile\ Documents/com~apple~CloudDocs/

# If none found, fall back to asking the user
```

### Multiple Google Drive accounts

Users may have multiple Google accounts synced:

```
~/Library/CloudStorage/GoogleDrive-personal@gmail.com/
~/Library/CloudStorage/GoogleDrive-work@company.com/
```

If there are multiple, ask the user which one to use before proceeding.

---

## Mode 1: Agent Mode (CLI arguments)

**Best for:** LLM Agents (Claude, ChatGPT, etc.), automation scripts, or anyone who prefers typing straight into the terminal.

Just pass **source** and **destination** as arguments.

### Examples

```bash
# Backup photos to an external drive
rsync-transfer ~/Pictures /Volumes/Backup/MyPhotos

# Backup a project to Google Drive
rsync-transfer ~/development/my-project ~/Library/CloudStorage/GoogleDrive-<user>/My\ Drive/Backups/Projects

# Backup Downloads to iCloud
rsync-transfer ~/Downloads ~/Library/Mobile\ Documents/com~apple~CloudDocs/Backup/Downloads

# Dry-run — preview without actually copying
rsync-transfer --dry-run ~/Pictures /Volumes/Backup/MyPhotos
```

### When called by an AI Agent

```
Prompt: "Backup the Documents folder from Downloads to iCloud"

The agent will run:
# 1. Verify iCloud exists
ls ~/Library/Mobile\ Documents/com~apple~CloudDocs/
# 2. Run the transfer
rsync-transfer /Users/<user>/Downloads/Documents /Users/<user>/Library/Mobile\ Documents/com~apple~CloudDocs/Backup
```

### What the output looks like

```
────────────────────────────────────────
Pre-flight Summary
  Source:      /Users/<user>/Pictures
  Destination: /Volumes/Backup/MyPhotos
  Dry run:     No
  Files:       2451
  Size:        12G

[i] Checking disk space...
[✓] Source size: 12G
[✓] Available at destination: 500G

────────────────────────────────────────
Starting transfer
[i] Log: logs/transfer-20260624-211738.log

sending incremental file list
./
IMG_001.jpg
       10244 100%   16.93MB/s   00:00:00
IMG_002.jpg
      123456 100%   12.34MB/s   00:00:01
...
```

### Agent calling rules

| Rule | Detail |
|---|---|
| Arguments | `rsync-transfer <source> <dest>` |
| Source | Full path — must exist |
| Dest | Full path — parent directory must exist |
| Dry run | `rsync-transfer --dry-run <source> <dest>` |
| Exit code | `0` = success, `1` = error/warning |

---

## Mode 2: Manual Mode (interactive)

**Best for:** When you don't want to memorize paths or type long paths.

### Option A: Run and type paths on the spot

```bash
rsync-transfer --manual
```

The script will prompt you:

```
────────────────────────────────────────
rsync-transfer — Manual Mode

[!] MANUAL_SOURCE and MANUAL_DEST not configured.

Enter source path: ~/Pictures
Enter dest path:  /Volumes/Backup/MyPhotos
```

Just type or paste the paths. No need to remember argument order.

### Option B: Edit variables in the script (for recurring backups)

Open `rsync-transfer.sh` in a text editor. Find this section near the top:

```bash
# ============================== CONFIGURATION ===============================
MANUAL_SOURCE="/Users/<user>/Pictures"
MANUAL_DEST="/Volumes/Backup/MyPhotos"
```

Save the file, then just run:

```bash
rsync-transfer --manual
```

Want multiple backup targets? Just copy the script for each one:

```bash
cp rsync-transfer.sh backup-foto.sh
# Edit MANUAL_SOURCE and MANUAL_DEST in backup-foto.sh
./backup-foto.sh --manual
```

---

## Quick comparison

| | Agent Mode | Manual Mode |
|---|---|---|
| **Usage** | `rsync-transfer src dst` | `rsync-transfer --manual` |
| **Best for** | AI Agent, scripts, power users | People who don't want to type paths |
| **Arguments** | Passed directly in the command | Entered interactively or edited in script |
| **Dry-run** | `--dry-run src dst` | Use Agent mode temporarily |
| **Logging** | ✅ Automatic | ✅ Automatic |
| **Resume** | ✅ Just re-run | ✅ Just re-run |

---

## Testing: try a dry-run first

Not sure yet? Use `--dry-run`. It shows exactly which files would be copied without actually moving anything.

```bash
# Preview first
rsync-transfer --dry-run ~/Pictures /Volumes/Backup/MyPhotos

# If everything looks right, remove --dry-run
rsync-transfer ~/Pictures /Volumes/Backup/MyPhotos
```

---

## Important notes

- **Paths with spaces are fine** — just wrap them in quotes: `"~/My Folder"`
- **If transfer gets interrupted** (e.g. USB drive unplugged) — **just re-run**. rsync picks up where it left off.
- **Logs are saved** in the `logs/` folder — useful for checking what was transferred or debugging errors.
