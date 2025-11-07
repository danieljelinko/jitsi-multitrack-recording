#!/bin/bash
#
# Finalize Recording Hook
# This script is called by jitsi-multitrack-recorder when a recording finishes
#
# Arguments:
#   $1 - Recording file path (e.g., /recordings/room-timestamp.mka)
#

RECORDING_FILE="$1"
RECORDING_DIR=$(dirname "$RECORDING_FILE")
FILENAME=$(basename "$RECORDING_FILE" .mka)

# Log file
LOG_FILE="${RECORDING_DIR}/finalize.log"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=========================================="
log "Recording finalized: $RECORDING_FILE"
log "=========================================="

# Check if file exists
if [ ! -f "$RECORDING_FILE" ]; then
    log "ERROR: Recording file not found: $RECORDING_FILE"
    exit 1
fi

# Get file size
FILE_SIZE=$(stat -f%z "$RECORDING_FILE" 2>/dev/null || stat -c%s "$RECORDING_FILE" 2>/dev/null)
log "File size: $(numfmt --to=iec-i --suffix=B $FILE_SIZE 2>/dev/null || echo $FILE_SIZE bytes)"

# Use ffprobe to get recording info (if available)
if command -v ffprobe &> /dev/null; then
    log "Recording information:"

    # Get number of audio tracks
    NUM_TRACKS=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$RECORDING_FILE" | wc -l)
    log "  • Number of audio tracks: $NUM_TRACKS"

    # Get duration
    DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$RECORDING_FILE")
    log "  • Duration: $DURATION seconds"

    # List all tracks with codec info
    log "  • Track details:"
    ffprobe -v error -select_streams a -show_entries stream=index,codec_name,sample_rate,channels -of csv=p=0 "$RECORDING_FILE" | while IFS=',' read -r index codec sample_rate channels; do
        log "    - Track $index: $codec, ${sample_rate}Hz, ${channels}ch"
    done
else
    log "Warning: ffprobe not found. Install ffmpeg for detailed recording info."
fi

log "=========================================="
log "Recording ready for post-processing"
log "Location: $RECORDING_FILE"
log "=========================================="

# TODO: Add your custom post-processing here
# Examples:
# - Split into individual audio files per track
# - Upload to cloud storage
# - Trigger transcription service
# - Send notification

# Example: Create a marker file to signal post-processing system
touch "${RECORDING_FILE}.ready"
log "Created marker file: ${RECORDING_FILE}.ready"

exit 0
