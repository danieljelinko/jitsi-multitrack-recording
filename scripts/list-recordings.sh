#!/bin/bash
#
# List all recordings with details
#

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

RECORDING_DIR="./recordings"

echo -e "${BLUE}==================================${NC}"
echo -e "${BLUE}Jitsi Multitrack Recordings${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""

if [ ! -d "$RECORDING_DIR" ]; then
    echo -e "${YELLOW}No recordings directory found.${NC}"
    exit 0
fi

# Count recordings
NUM_RECORDINGS=$(find "$RECORDING_DIR" -name "*.mka" -type f 2>/dev/null | wc -l)

if [ "$NUM_RECORDINGS" -eq 0 ]; then
    echo -e "${YELLOW}No recordings found.${NC}"
    echo ""
    echo "Recordings will appear here after meetings are recorded."
    echo "Location: $RECORDING_DIR"
    echo ""
    exit 0
fi

echo -e "${GREEN}Found $NUM_RECORDINGS recording(s):${NC}"
echo ""

# List recordings with details
find "$RECORDING_DIR" -name "*.mka" -type f | sort -r | while read -r file; do
    filename=$(basename "$file")
    filesize=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    filesize_human=$(numfmt --to=iec-i --suffix=B "$filesize" 2>/dev/null || echo "$filesize bytes")
    modified=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1)

    echo -e "${GREEN}●${NC} $filename"
    echo "  Size: $filesize_human"
    echo "  Date: $modified"

    # If ffprobe is available, show track count
    if command -v ffprobe &> /dev/null; then
        num_tracks=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$file" 2>/dev/null | wc -l)
        duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
        if [ -n "$duration" ]; then
            duration_formatted=$(printf '%d:%02d:%02d\n' $((${duration%.*}/3600)) $((${duration%.*}%3600/60)) $((${duration%.*}%60)))
            echo "  Tracks: $num_tracks"
            echo "  Duration: $duration_formatted"
        fi
    fi

    echo ""
done

echo "Total recordings: $NUM_RECORDINGS"
echo ""
