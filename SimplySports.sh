#!/bin/sh
# SimplySports Plugin Installation Script

PLUGIN_PATH="/usr/lib/enigma2/python/Plugins/Extensions"
PLUGIN_NAME="SimplySports"
REPO_URL="https://github.com/Ahmed-Mohammed-Abbas/SimplySports/archive/refs/heads/main.zip"
TEMP_ZIP="/tmp/${PLUGIN_NAME}_$$.zip"  # Added PID for uniqueness
LOG="/tmp/${PLUGIN_NAME}_install.log"

# Logging function
log_msg() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

# Cleanup function
cleanup() {
    rm -f "$TEMP_ZIP" 2>/dev/null
    log_msg "Cleanup: Temporary files removed."
}

# Set trap for exit signals
trap cleanup EXIT INT TERM

# Start installation
log_msg "Starting SimplySports installation..."

# Check if we have write permissions
if [ ! -w "$PLUGIN_PATH" ]; then
    log_msg "ERROR: No write permission to $PLUGIN_PATH"
    echo "PROGRESS:ERROR - Permission denied"
    exit 1
fi

# 1. Navigate to plugins directory
log_msg "Navigating to plugins directory: $PLUGIN_PATH"
cd "$PLUGIN_PATH" || {
    log_msg "ERROR: Failed to change directory to $PLUGIN_PATH"
    exit 1
}

# 2. Remove existing plugin if present
if [ -d "$PLUGIN_NAME" ]; then
    log_msg "Removing existing plugin directory..."
    if rm -rf "$PLUGIN_NAME" 2>/dev/null; then
        log_msg "Existing plugin removed successfully"
    else
        log_msg "WARNING: Could not remove existing plugin"
    fi
else
    log_msg "No existing plugin found, proceeding with fresh install..."
fi

# 3. Download plugin
log_msg "Downloading plugin from: $REPO_URL"
if ! wget --no-check-certificate -q --show-progress -O "$TEMP_ZIP" "$REPO_URL" 2>&1 | tee -a "$LOG"; then
    log_msg "ERROR: Download failed. Check internet connection or repository URL."
    exit 1
fi

# Verify downloaded file
if [ ! -f "$TEMP_ZIP" ] || [ ! -s "$TEMP_ZIP" ]; then
    log_msg "ERROR: Downloaded file is empty or missing"
    exit 1
fi

FILE_SIZE=$(stat -c%s "$TEMP_ZIP" 2>/dev/null || stat -f%z "$TEMP_ZIP" 2>/dev/null)
log_msg "Downloaded file size: $FILE_SIZE bytes"

# 4. Extract plugin
log_msg "Extracting plugin..."
if ! unzip -qo "$TEMP_ZIP" -d "$PLUGIN_PATH" 2>&1 | tee -a "$LOG"; then
    log_msg "ERROR: Extraction failed"
    exit 1
fi

# 5. Rename extracted folder
log_msg "Renaming extracted folder..."
if [ -d "SimplySports-main" ]; then
    if [ -d "$PLUGIN_NAME" ]; then
        rm -rf "$PLUGIN_NAME" 2>/dev/null
    fi
    if mv "SimplySports-main" "$PLUGIN_NAME" 2>/dev/null; then
        log_msg "Folder renamed successfully"
    else
        log_msg "ERROR: Failed to rename folder"
        exit 1
    fi
else
    log_msg "ERROR: Extracted folder 'SimplySports-main' not found"
    exit 1
fi

# 6. Set permissions
log_msg "Setting permissions..."
if [ -d "$PLUGIN_NAME" ]; then
    find "$PLUGIN_NAME" -type f -exec chmod 644 {} \; 2>/dev/null
    find "$PLUGIN_NAME" -type d -exec chmod 755 {} \; 2>/dev/null
    log_msg "Permissions set successfully"
else
    log_msg "WARNING: Plugin directory not found for permissions"
fi

# 7. Clean up temporary zip file
rm -f "$TEMP_ZIP" 2>/dev/null

# 8. Restart Enigma2 GUI
log_msg "Restarting Enigma2 GUI..."
if command -v killall >/dev/null 2>&1; then
    if killall -9 enigma2 2>/dev/null; then
        log_msg "Enigma2 restarted successfully"
    else
        log_msg "WARNING: Could not kill Enigma2 process"
        log_msg "Please restart Enigma2 manually"
    fi
else
    log_msg "WARNING: killall command not found. Please restart Enigma2 manually"
fi

# Completion
log_msg "SUCCESS: SimplySports plugin installed successfully!"
log_msg "Plugin installed at: $PLUGIN_PATH/$PLUGIN_NAME"
echo "PROGRESS:100 - Installation Complete"
exit 0
