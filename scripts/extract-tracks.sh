#!/bin/bash
#
# Extract individual audio tracks from MKA recording
# Requires: ffmpeg
#

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ $# -lt 1 ]; then
    echo "Usage: $0 <recording.mka> [output_format]"
    echo ""
    echo "Arguments:"
    echo "  recording.mka  - Path to the MKA recording file"
    echo "  output_format  - Optional output format (wav, flac, opus, mp3) [default: wav]"
    echo ""
    echo "Example:"
    echo "  $0 recordings/room-2025-01-15-10-30-00.mka wav"
    echo ""
    exit 1
fi

RECORDING_FILE="$1"
OUTPUT_FORMAT="${2:-wav}"

# Check if file exists
if [ ! -f "$RECORDING_FILE" ]; then
    echo -e "${RED}Error: File not found: $RECORDING_FILE${NC}"
    exit 1
fi

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo -e "${RED}Error: ffmpeg not found!${NC}"
    echo "Please install ffmpeg:"
    echo "  • Ubuntu/Debian: sudo apt-get install ffmpeg"
    echo "  • macOS: brew install ffmpeg"
    echo ""
    exit 1
fi

# Get file info
FILENAME=$(basename "$RECORDING_FILE" .mka)
OUTPUT_DIR=$(dirname "$RECORDING_FILE")/extracted_${FILENAME}

echo -e "${BLUE}==================================${NC}"
echo -e "${BLUE}Extracting Audio Tracks${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""
echo "Input file: $RECORDING_FILE"
echo "Output format: $OUTPUT_FORMAT"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Get number of audio tracks
NUM_TRACKS=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$RECORDING_FILE" | wc -l)

if [ "$NUM_TRACKS" -eq 0 ]; then
    echo -e "${RED}Error: No audio tracks found in recording!${NC}"
    exit 1
fi

echo -e "${GREEN}Found $NUM_TRACKS audio track(s)${NC}"
echo ""

# Extract each track
TRACK_INDEX=0
while [ $TRACK_INDEX -lt $NUM_TRACKS ]; do
    OUTPUT_FILE="${OUTPUT_DIR}/track_${TRACK_INDEX}.${OUTPUT_FORMAT}"

    echo -e "${BLUE}Extracting track $((TRACK_INDEX + 1))/${NUM_TRACKS}...${NC}"

    # Set encoding parameters based on format
    case "$OUTPUT_FORMAT" in
        wav)
            CODEC_PARAMS="-acodec pcm_s16le"
            ;;
        flac)
            CODEC_PARAMS="-acodec flac"
            ;;
        opus)
            CODEC_PARAMS="-acodec libopus -b:a 128k"
            ;;
        mp3)
            CODEC_PARAMS="-acodec libmp3lame -b:a 192k"
            ;;
        *)
            echo -e "${RED}Unsupported format: $OUTPUT_FORMAT${NC}"
            echo "Supported formats: wav, flac, opus, mp3"
            exit 1
            ;;
    esac

    # Extract track
    ffmpeg -v error -i "$RECORDING_FILE" -map 0:a:$TRACK_INDEX $CODEC_PARAMS "$OUTPUT_FILE"

    if [ $? -eq 0 ]; then
        FILE_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
        FILE_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B "$FILE_SIZE" 2>/dev/null || echo "$FILE_SIZE bytes")
        echo -e "${GREEN}✓ Saved: $(basename "$OUTPUT_FILE") ($FILE_SIZE_HUMAN)${NC}"
    else
        echo -e "${RED}✗ Failed to extract track $TRACK_INDEX${NC}"
    fi

    echo ""
    TRACK_INDEX=$((TRACK_INDEX + 1))
done

echo -e "${BLUE}==================================${NC}"
echo -e "${GREEN}Extraction complete!${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""
echo "Extracted tracks saved to:"
echo "  $OUTPUT_DIR"
echo ""
echo "Files:"
ls -lh "$OUTPUT_DIR" | tail -n +2
echo ""
