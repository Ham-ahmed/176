#!/bin/sh
# Complete channel list for all satellites

MANUAL_URL="https://raw.githubusercontent.com/Ham-ahmed/176/refs/heads/main/channels_backup_OpenBH_20260616_HAZEMWAHBA.tar.gz"

URL=${1:-$MANUAL_URL}
TARGET=${2:-"/tmp/extracted"}  # Default target if not specified
TMP_FILE="/tmp/master_pkg_$$"   # Added PID to avoid conflicts
LOG="/tmp/channel_master.log"

# Ensure log file exists and is writable
touch "$LOG" 2>/dev/null || LOG="/dev/null"

log_msg() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

# Cleanup function for trap
cleanup() {
    rm -f "$TMP_FILE" 2>/dev/null
    log_msg "Cleanup: Temporary files removed."
}

# Set trap for exit signals
trap cleanup EXIT INT TERM

# START: 10% Progress
echo "PROGRESS:10"
log_msg "Installation Started..."

# 1. Dependency Check (Unzip)
if echo "$URL" | grep -qi ".zip" && ! command -v unzip > /dev/null 2>&1; then
    log_msg "Action: Installing dependencies..."
    if opkg update > /dev/null 2>&1 && opkg install unzip > /dev/null 2>&1; then
        log_msg "Dependencies installed successfully."
    else
        log_msg "WARNING: Failed to install unzip, but continuing..."
    fi
fi

echo "PROGRESS:30"
log_msg "Action: Downloading package from: $URL"

# Check if URL is valid before downloading
if ! wget -q --no-check-certificate -O "$TMP_FILE" "$URL"; then
    log_msg "ERROR: Download failed. Check URL or network connectivity."
    exit 1
fi

# Verify file size
FILE_SIZE=$(stat -c%s "$TMP_FILE" 2>/dev/null || stat -f%z "$TMP_FILE" 2>/dev/null)
if [ -z "$FILE_SIZE" ] || [ "$FILE_SIZE" -lt 1000 ]; then
    log_msg "ERROR: Downloaded file seems corrupted or empty (size: $FILE_SIZE bytes)."
    exit 1
fi

# 4. Extraction: 60% Progress
echo "PROGRESS:60"
case "$URL" in
    *.ipk|*.IPK)
        log_msg "Action: Installing IPK via Opkg..."
        if opkg install "$TMP_FILE" 2>&1 | tee -a "$LOG"; then
            RESULT=0
        else
            RESULT=$?
        fi
        ;;
    *.zip|*.ZIP)
        log_msg "Action: Extracting ZIP to $TARGET..."
        mkdir -p "$TARGET"
        if unzip -qo "$TMP_FILE" -d "$TARGET" 2>&1 | tee -a "$LOG"; then
            RESULT=0
        else
            RESULT=$?
        fi
        ;;
    *.tar.gz|*.tgz|*.TAR.GZ)
        if [ -n "$TARGET" ] && [ "$TARGET" != "/" ]; then
            log_msg "Action: Extracting Tar.gz to $TARGET..."
            mkdir -p "$TARGET"
            if tar -xzf "$TMP_FILE" -C "$TARGET" 2>&1 | tee -a "$LOG"; then
                RESULT=0
            else
                RESULT=$?
            fi
        else
            log_msg "Action: Extracting Tar.gz to System Root..."
            if tar -xzf "$TMP_FILE" -C / 2>&1 | tee -a "$LOG"; then
                RESULT=0
            else
                RESULT=$?
            fi
        fi
        ;;
    *)
        log_msg "ERROR: Unsupported Format. Supported: .ipk, .zip, .tar.gz"
        exit 1
        ;;
esac

# 5. Permissions: 80% Progress
echo "PROGRESS:80"
if [ $RESULT -eq 0 ] && [ -n "$TARGET" ] && [ "$TARGET" != "/" ] && [ -d "$TARGET" ]; then
    log_msg "Action: Fixing permissions (755)..."
    find "$TARGET" -type f -exec chmod 755 {} \; 2>/dev/null
    find "$TARGET" -type d -exec chmod 755 {} \; 2>/dev/null
    log_msg "Permissions updated."
fi

# 6. Finalize: 100% Progress
echo "PROGRESS:100"
if [ $RESULT -eq 0 ]; then
    log_msg "SUCCESS: Installation Finished."
    log_msg "Files extracted to: $TARGET"
    exit 0
else
    log_msg "ERROR: Installation Failed. Exit code: $RESULT"
    exit $RESULT
fi