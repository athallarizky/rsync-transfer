# rsync-transfer

<img width="1501" height="803" alt="image" src="https://github.com/user-attachments/assets/cc1607f0-3bbf-432a-b8d2-5269ba25f209" />

Reusable data transfer script using rsync. Resumable, progress bars, space checks, trailing-space fix, logging.

## Usage

### Agent mode (for LLM / CLI)
```bash
./rsync-transfer.sh /path/to/source /path/to/dest
./rsync-transfer.sh --dry-run /path/to/source /path/to/dest  # preview
```

### Manual mode
```bash
./rsync-transfer.sh --manual
```
Then enter paths interactively, or edit `MANUAL_SOURCE` and `MANUAL_DEST` at the top of the script.

## Features
- Resumable transfers (`--partial`)
- Real-time progress per file
- Disk space check before transfer
- Fixes trailing-space folder names automatically
- Logs every transfer to `logs/`
- Dry-run for preview

## Installation (optional)
```bash
ln -s "$PWD/rsync-transfer.sh" ~/.local/bin/rsync-transfer
```
Then use from anywhere: `rsync-transfer source dest`
