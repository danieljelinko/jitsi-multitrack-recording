# Testing Instructions for Local Claude Code Agent

## Objective
Test the Jitsi multitrack recording server on localhost and verify all functionality works correctly.

## Quick Start Commands

Execute these commands in order:

### 1. Clone and Setup
```bash
cd ~/workspace
git clone https://github.com/danieljelinko/jitsi-multitrack-recording.git
cd jitsi-multitrack-recording
```

### 2. Generate Configuration
```bash
./scripts/generate-passwords.sh
# When prompted:
# - PUBLIC_URL: Press Enter (accept default http://localhost:8000)
# - Auto-recording: Type "yes" and press Enter
```

### 3. Start the Server
```bash
./scripts/start-server.sh
```

Wait for all services to start (10-20 seconds).

### 4. Verify Services Running
```bash
docker-compose ps
```

**Expected:** All 5 services should show "Up" status.

### 5. Test Web Interface
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000
```

**Expected output:** `200`

### 6. Conduct Test Meeting

You need to test with a browser. Provide these instructions to the user:

**Manual Step Required:**
1. Open browser: `http://localhost:8000`
2. Enter room name: `test-recording-001`
3. Allow microphone/camera permissions
4. Open 2 more browser tabs/windows (incognito mode) with same URL
5. Have each "participant" speak clearly for 30 seconds:
   - Participant 1: "This is participant one testing..."
   - Participant 2: "This is participant two testing..."
   - Participant 3: "This is participant three testing..."
6. Keep meeting running for at least 2 minutes
7. Close all tabs to end meeting

### 7. Verify Recording Created

Wait 10 seconds after meeting ends, then:

```bash
./scripts/list-recordings.sh
```

**Expected output:** Should show 1 recording with:
- Non-zero file size
- 3 audio tracks
- Duration ~2 minutes

### 8. Extract Audio Tracks
```bash
# Get the recording filename
RECORDING_FILE=$(ls -t recordings/*.mka | head -1)

# Extract tracks as WAV
./scripts/extract-tracks.sh "$RECORDING_FILE" wav
```

**Expected output:** 3 WAV files created, one per participant.

### 9. Verify Track Separation

```bash
# List extracted files
ls -lh recordings/extracted_*/

# Check track 0 metadata
ffprobe recordings/extracted_*/track_0.wav 2>&1 | grep "Duration\|Audio"
```

**Expected:**
- 3 separate files (track_0.wav, track_1.wav, track_2.wav)
- Each file size: 5-10MB
- Duration matches meeting length

### 10. Audio Playback Verification

**Manual Step Required:** Ask user to play the extracted files:

**Linux:**
```bash
vlc recordings/extracted_*/track_0.wav
vlc recordings/extracted_*/track_1.wav
vlc recordings/extracted_*/track_2.wav
```

**macOS:**
```bash
afplay recordings/extracted_*/track_0.wav
afplay recordings/extracted_*/track_1.wav
afplay recordings/extracted_*/track_2.wav
```

**Verification:** Each track should contain ONLY one participant's voice (isolated, not mixed).

### 11. Test Multiple Formats

```bash
# Extract as FLAC
./scripts/extract-tracks.sh "$RECORDING_FILE" flac

# Extract as MP3
./scripts/extract-tracks.sh "$RECORDING_FILE" mp3

# Verify all formats created
ls -lh recordings/extracted_*/
```

### 12. Cleanup
```bash
./scripts/stop-server.sh
```

---

## Full Testing Guide

For complete step-by-step instructions with expected outputs, troubleshooting, and detailed verification steps, see:

**[docs/LOCALHOST_TESTING.md](docs/LOCALHOST_TESTING.md)**

This comprehensive guide includes:
- Prerequisites verification
- Detailed expected outputs for every step
- Troubleshooting common issues
- Success/failure criteria
- Testing checklist

---

## Quick Success Check

**✅ Test PASSED if:**

1. All containers start without errors
2. Web interface loads at http://localhost:8000
3. Recording file created after meeting
4. Recording contains 3 tracks (one per participant)
5. Tracks extract successfully to separate WAV files
6. Each track plays only one participant's voice (isolated)
7. Audio quality is clear

**❌ Test FAILED if:**

- Any container fails to start
- No recording file created
- Recording file is 0 bytes
- Wrong number of tracks
- Audio extraction fails
- Tracks contain mixed audio (multiple voices per track)

---

## Automated Testing Script (Optional)

If you want to automate the non-browser parts:

```bash
#!/bin/bash
# Save as test-suite.sh

set -e

echo "1. Generating configuration..."
echo -e "\n\nyes" | ./scripts/generate-passwords.sh

echo "2. Starting server..."
./scripts/start-server.sh

echo "3. Waiting for services..."
sleep 15

echo "4. Checking services..."
docker-compose ps

echo "5. Testing web interface..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000)
if [ "$STATUS" -eq 200 ]; then
    echo "✓ Web interface responding"
else
    echo "✗ Web interface not responding (HTTP $STATUS)"
    exit 1
fi

echo ""
echo "================================================"
echo "MANUAL STEP REQUIRED"
echo "================================================"
echo ""
echo "Please conduct a test meeting:"
echo "1. Open browser: http://localhost:8000"
echo "2. Create room: test-recording-001"
echo "3. Join with 3 participants"
echo "4. Speak for 2 minutes"
echo "5. End meeting"
echo ""
echo "Press Enter when meeting is complete..."
read

echo "6. Waiting for recording to finalize..."
sleep 10

echo "7. Listing recordings..."
./scripts/list-recordings.sh

echo "8. Extracting tracks..."
RECORDING_FILE=$(ls -t recordings/*.mka | head -1)
./scripts/extract-tracks.sh "$RECORDING_FILE" wav

echo "9. Verifying extracted files..."
TRACK_COUNT=$(ls recordings/extracted_*/track_*.wav 2>/dev/null | wc -l)
if [ "$TRACK_COUNT" -eq 3 ]; then
    echo "✓ Extracted $TRACK_COUNT tracks (expected 3)"
else
    echo "✗ Extracted $TRACK_COUNT tracks (expected 3)"
    exit 1
fi

echo ""
echo "================================================"
echo "VERIFICATION REQUIRED"
echo "================================================"
echo ""
echo "Please play the audio files to verify isolation:"
echo "  vlc recordings/extracted_*/track_0.wav"
echo "  vlc recordings/extracted_*/track_1.wav"
echo "  vlc recordings/extracted_*/track_2.wav"
echo ""
echo "Each track should contain only ONE participant's voice."
echo ""
echo "Does each track contain isolated audio? (yes/no): "
read ANSWER

if [[ $ANSWER =~ ^[Yy][Ee][Ss]$ ]]; then
    echo ""
    echo "✅ TEST PASSED!"
    echo ""
else
    echo ""
    echo "❌ TEST FAILED - Audio tracks not properly isolated"
    echo ""
    exit 1
fi

echo "Stopping server..."
./scripts/stop-server.sh

echo ""
echo "Testing complete!"
```

Make executable and run:
```bash
chmod +x test-suite.sh
./test-suite.sh
```

---

## Expected Timeline

- **Setup (Steps 1-3):** 5-10 minutes (first time, includes Docker image pull)
- **Service start (Step 4):** 10-20 seconds
- **Manual meeting test (Step 6):** 3-5 minutes
- **Verification (Steps 7-10):** 2-3 minutes
- **Total:** ~15-20 minutes

---

## Need Help?

- **Detailed Guide:** See [docs/LOCALHOST_TESTING.md](docs/LOCALHOST_TESTING.md)
- **Architecture Info:** See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **Full Documentation:** See [README.md](README.md)

---

**Good luck with testing!**
