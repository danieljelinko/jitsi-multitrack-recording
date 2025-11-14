# Localhost Testing Instructions - Jitsi Multitrack Recording

**Purpose:** Test the Jitsi multitrack recording server on localhost to verify all functionality works correctly.

**Target User:** Local Claude Code agent or developer testing the system

**Time Required:** 30-45 minutes

---

## Prerequisites Check

Before starting, verify all required software is installed:

### Step 1: Check Docker Installation

```bash
docker --version
```

**Expected Output:** `Docker version 20.10.x` or higher

**If not installed:**
- Ubuntu/Debian: `sudo apt-get update && sudo apt-get install -y docker.io`
- macOS: Install Docker Desktop from https://www.docker.com/products/docker-desktop
- Windows: Install Docker Desktop from https://www.docker.com/products/docker-desktop

### Step 2: Check Docker Compose Installation

```bash
docker-compose --version
```

**Expected Output:** `docker-compose version 1.29.x` or higher

**If not installed:**
- Ubuntu/Debian: `sudo apt-get install -y docker-compose`
- macOS/Windows: Included with Docker Desktop

### Step 3: Verify Docker is Running

```bash
docker info
```

**Expected Output:** Docker system information (server version, containers, images, etc.)

**If Docker is not running:**
- Ubuntu/Debian: `sudo systemctl start docker`
- macOS/Windows: Start Docker Desktop application

### Step 4: Add User to Docker Group (Linux only)

```bash
sudo usermod -aG docker $USER
```

**Then log out and log back in**, or run:
```bash
newgrp docker
```

### Step 5: Verify FFmpeg (Optional but Recommended)

```bash
ffmpeg -version
```

**Expected Output:** FFmpeg version information

**If not installed:**
- Ubuntu/Debian: `sudo apt-get install -y ffmpeg`
- macOS: `brew install ffmpeg`
- Windows: Download from https://ffmpeg.org/download.html

---

## Part 1: Clone and Setup

### Step 1.1: Clone the Repository

```bash
# Navigate to your workspace
cd ~/workspace  # Or your preferred directory

# Clone the repository
git clone https://github.com/danieljelinko/jitsi-multitrack-recording.git

# Navigate into the directory
cd jitsi-multitrack-recording
```

**Verify:**
```bash
ls -la
```

**Expected Output:** Should show files including:
- `README.md`
- `docker-compose.yml`
- `.env.example`
- `scripts/` directory
- `config/` directory
- `recordings/` directory
- `docs/` directory

### Step 1.2: Verify Directory Structure

```bash
ls -la scripts/
```

**Expected Output:** Should show 7 executable scripts:
- `generate-passwords.sh`
- `start-server.sh`
- `stop-server.sh`
- `view-logs.sh`
- `list-recordings.sh`
- `extract-tracks.sh`
- `finalize-recording.sh`

All should have execute permissions (`-rwxr-xr-x`).

**If scripts are not executable:**
```bash
chmod +x scripts/*.sh
```

### Step 1.3: Generate Configuration

```bash
./scripts/generate-passwords.sh
```

**Interactive Prompts:**

1. **PUBLIC_URL prompt:** Press `Enter` to accept default `http://localhost:8000`
2. **Auto-recording prompt:** Type `yes` and press `Enter` (or just press `Enter` for default)

**Expected Output:**
```
==================================
Jitsi Multitrack Recording Setup
Password Generation Script
==================================

Generating secure random passwords...

✓ Passwords generated successfully!

Configuration:
  - JICOFO_COMPONENT_SECRET: ******** (hidden)
  - JICOFO_AUTH_PASSWORD: ******** (hidden)
  - JVB_AUTH_PASSWORD: ******** (hidden)
  - JIBRI_RECORDER_PASSWORD: ******** (hidden)

The .env file has been created with secure passwords.

✓ PUBLIC_URL set to: http://localhost:8000

✓ Auto-recording enabled

==================================
Setup complete!
==================================

Next steps:
  1. Review .env file and adjust settings if needed
  2. Run: ./scripts/start-server.sh to start Jitsi
  3. Access Jitsi at: http://localhost:8000
  4. Recordings will be stored in: ./recordings/
```

### Step 1.4: Verify .env File Created

```bash
ls -la .env
```

**Expected Output:** `.env` file exists with recent timestamp

**Verify contents (optional):**
```bash
cat .env | grep -E "^(PUBLIC_URL|ENABLE_AUTO_RECORDING|JICOFO_COMPONENT_SECRET)" | head -3
```

**Expected Output:** Should show your configuration with real values (not CHANGEME)

---

## Part 2: Start the Server

### Step 2.1: Start All Services

```bash
./scripts/start-server.sh
```

**Expected Output:**
```
==================================
Starting Jitsi Multitrack Recording
==================================

ℹ Starting Jitsi services...

Pulling Docker images...
[Docker will pull images - FIRST TIME ONLY, takes 5-10 minutes]

Starting containers...
Creating network "jitsi-multitrack-recording_meet.jitsi" with driver "bridge"
Creating jitsi_prosody ... done
Creating jitsi_multitrack_recorder ... done
Creating jitsi_web ... done
Creating jitsi_jicofo ... done
Creating jitsi_jvb ... done

✓ Services started successfully!

ℹ Waiting for services to be ready...

Service Status:
     Name                   Command               State                    Ports
----------------------------------------------------------------------------------------------------
jitsi_jicofo            /init                         Up
jitsi_jvb               /init                         Up      0.0.0.0:10000->10000/udp, ...
jitsi_multitrack_recorder  /init                      Up      0.0.0.0:8989->8989/tcp
jitsi_prosody           /init                         Up      5222/tcp, 5280/tcp, 5347/tcp
jitsi_web               /init                         Up      0.0.0.0:8000->80/tcp, ...

==================================
Jitsi is now running!
==================================

Access Jitsi Meet at:
  http://localhost:8000

Recordings location:
  /path/to/jitsi-multitrack-recording/recordings/

...
✓ Auto-recording is ENABLED
  Meetings will be automatically recorded when started.
```

### Step 2.2: Verify All Containers Are Running

```bash
docker-compose ps
```

**Expected Output:** All services should show "Up" state:
```
Name                          State    Ports
---------------------------------------------------------------
jitsi_jicofo                  Up
jitsi_jvb                     Up       0.0.0.0:10000->10000/udp
jitsi_multitrack_recorder     Up       0.0.0.0:8989->8989/tcp
jitsi_prosody                 Up       5222/tcp, 5280/tcp
jitsi_web                     Up       0.0.0.0:8000->80/tcp
```

**If any service shows "Exit" or "Restarting":**
```bash
# Check logs for that service
./scripts/view-logs.sh <service-name>

# Example:
./scripts/view-logs.sh jvb
```

### Step 2.3: Verify Web Server is Responding

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000
```

**Expected Output:** `200`

**If you get connection error:**
- Wait 10-20 seconds for services to fully start
- Try again
- Check logs: `./scripts/view-logs.sh web`

### Step 2.4: Check Recorder is Ready

```bash
./scripts/view-logs.sh recorder | tail -20
```

**Look for:** Lines indicating WebSocket server is listening on port 8989
- Should NOT see error messages
- Should see successful startup messages

---

## Part 3: Test Web Interface

### Step 3.1: Access Web Interface

**Option A: If you have a GUI browser available**

Open your web browser and navigate to:
```
http://localhost:8000
```

**Option B: If running headless/remote**

On your local machine with a browser, use SSH port forwarding:
```bash
ssh -L 8000:localhost:8000 user@remote-server
```

Then open browser to: `http://localhost:8000`

### Step 3.2: Verify Jitsi Meet Loads

**Expected:** You should see:
- Jitsi Meet interface
- Text field to enter a room name
- "Go" button or similar
- No error messages in browser console

**Take note:** The interface should load without SSL/certificate errors (we're using HTTP for localhost testing).

---

## Part 4: Conduct Test Recording

### Step 4.1: Create a Test Meeting Room

In the browser:
1. Enter a room name: `test-recording-001`
2. Click "Go" or press Enter

**Expected:**
- Browser prompts for microphone/camera permissions
- Click "Allow" or "Accept"
- You should see yourself on video
- Audio level indicator should respond to your voice

### Step 4.2: Simulate Multiple Participants

**Important:** For true multitrack testing, you need at least 2 participants.

**Method 1: Multiple Browser Tabs (Quick Test)**

1. **Keep first tab open** (you're already in the meeting)
2. **Open a new incognito/private window**
   - Chrome: Ctrl+Shift+N (Windows/Linux) or Cmd+Shift+N (Mac)
   - Firefox: Ctrl+Shift+P (Windows/Linux) or Cmd+Shift+P (Mac)
3. **Navigate to:** `http://localhost:8000/test-recording-001`
4. **Allow permissions** again
5. **Repeat for 3rd participant** (another incognito window or different browser)

**Method 2: Multiple Devices (Best Test)**

1. **Find your computer's local IP address:**
   ```bash
   # Linux
   ip addr show | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | cut -d/ -f1

   # macOS
   ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}'
   ```

   **Example output:** `192.168.1.100`

2. **On another device** (phone, tablet, another computer) on the same WiFi network:
   - Open browser
   - Navigate to: `http://192.168.1.100:8000/test-recording-001`
   - Replace `192.168.1.100` with your actual IP

### Step 4.3: Verify Participants Can Communicate

**Check that:**
- All participants can see each other's video
- All participants can hear each other
- Audio level indicators respond to speech
- No significant lag or freezing

### Step 4.4: Record Test Audio

**To make testing easier, have each participant speak clearly:**

**Participant 1:** "This is participant one. I am testing the Jitsi multitrack recording system. One, two, three, four, five."

**Wait 2 seconds**

**Participant 2:** "This is participant two. I am testing the multitrack audio recording. Five, four, three, two, one."

**Wait 2 seconds**

**Participant 3:** "Participant three here. Testing audio isolation and quality. Testing, one, two, three."

**Continue for at least 2 minutes total** to ensure a meaningful recording.

### Step 4.5: Check Recording Status

While meeting is in progress, check recorder logs:

```bash
./scripts/view-logs.sh recorder | tail -30
```

**Look for:**
- Messages indicating recording session started
- WebSocket connection established
- No error messages

### Step 4.6: End the Meeting

**In browser:** Have all participants leave the meeting
- Click "Leave" or "Hang up" button
- Close all meeting tabs

**Wait 10-30 seconds** for recording to finalize.

---

## Part 5: Verify Recording

### Step 5.1: Check Recordings Directory

```bash
ls -lh recordings/
```

**Expected Output:** Should show at least one `.mka` file:
```
total 2.5M
-rw-r--r-- 1 user user 2.5M Nov  7 10:32 room-2025-11-07-10-30-15.mka
-rw-r--r-- 1 user user    0 Nov  7 10:32 room-2025-11-07-10-30-15.mka.ready
```

**Note:** Filename format is `room-<timestamp>.mka`

**If no recording file:**
```bash
# Check recorder logs for errors
./scripts/view-logs.sh recorder | grep -i "error\|exception\|fail"

# Check if finalize script ran
cat recordings/finalize.log
```

### Step 5.2: Use List Recordings Script

```bash
./scripts/list-recordings.sh
```

**Expected Output:**
```
==================================
Jitsi Multitrack Recordings
==================================

Found 1 recording(s):

● room-2025-11-07-10-30-15.mka
  Size: 2.5MB
  Date: 2025-11-07 10:32:15
  Tracks: 3
  Duration: 0:02:15

Total recordings: 1
```

**Key checks:**
- ✅ File exists
- ✅ Size is reasonable (not 0 bytes)
- ✅ Track count matches participant count (3 in this example)
- ✅ Duration matches meeting length (~2 minutes in this example)

### Step 5.3: Inspect Recording with FFprobe

```bash
# Replace filename with your actual recording
ffprobe recordings/room-*.mka
```

**Expected Output:** Detailed info including:
```
Input #0, matroska,webm, from 'recordings/room-2025-11-07-10-30-15.mka':
  Duration: 00:02:15.xx, start: 0.000000, bitrate: xxx kb/s
    Stream #0:0: Audio: opus, 48000 Hz, mono, fltp
    Stream #0:1: Audio: opus, 48000 Hz, mono, fltp
    Stream #0:2: Audio: opus, 48000 Hz, mono, fltp
```

**Important:** Verify you see **multiple audio streams** (one per participant).

---

## Part 6: Extract and Verify Audio Tracks

### Step 6.1: Extract Tracks to WAV

```bash
./scripts/extract-tracks.sh recordings/room-*.mka wav
```

**Expected Output:**
```
==================================
Extracting Audio Tracks
==================================
Input file: recordings/room-2025-11-07-10-30-15.mka
Output format: wav
Output directory: recordings/extracted_room-2025-11-07-10-30-15

Found 3 audio track(s)

Extracting track 1/3...
✓ Saved: track_0.wav (5.2MB)

Extracting track 2/3...
✓ Saved: track_1.wav (5.1MB)

Extracting track 3/3...
✓ Saved: track_2.wav (4.9MB)

==================================
Extraction complete!
==================================

Extracted tracks saved to:
  recordings/extracted_room-2025-11-07-10-30-15
```

### Step 6.2: Verify Extracted Files

```bash
ls -lh recordings/extracted_*/
```

**Expected Output:**
```
total 15M
-rw-r--r-- 1 user user 5.2M Nov  7 10:35 track_0.wav
-rw-r--r-- 1 user user 5.1M Nov  7 10:35 track_1.wav
-rw-r--r-- 1 user user 4.9M Nov  7 10:35 track_2.wav
```

**Checks:**
- ✅ One file per participant
- ✅ File sizes are reasonable (5-10MB per minute of audio)
- ✅ No zero-byte files

### Step 6.3: Verify Audio File Metadata

```bash
ffprobe recordings/extracted_*/track_0.wav 2>&1 | grep "Duration\|Audio"
```

**Expected Output:**
```
Duration: 00:02:15.xx, bitrate: xxx kb/s
Stream #0:0: Audio: pcm_s16le, 48000 Hz, 1 channels, s16, 768 kb/s
```

**Checks:**
- ✅ Duration matches meeting length
- ✅ Audio codec is PCM (uncompressed)
- ✅ Sample rate is 48000 Hz
- ✅ 1 channel (mono)

### Step 6.4: Play Audio Files to Verify Content

**Linux:**
```bash
# Install if needed: sudo apt-get install vlc
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

**Windows (WSL):**
```bash
# Open in Windows Explorer
explorer.exe recordings/extracted_*
# Then double-click files to play with Windows Media Player
```

**Verification Checklist:**
- [ ] Track 0 contains ONLY participant 1's voice
- [ ] Track 1 contains ONLY participant 2's voice
- [ ] Track 2 contains ONLY participant 3's voice
- [ ] No voices are mixed (each track is isolated)
- [ ] Audio quality is clear
- [ ] No significant distortion or artifacts

**Expected Results:**
- When you play track_0.wav, you should hear: "This is participant one. I am testing..."
- When you play track_1.wav, you should hear: "This is participant two. I am testing..."
- When you play track_2.wav, you should hear: "Participant three here. Testing audio..."

---

## Part 7: Test Multiple Recordings

### Step 7.1: Conduct Second Test Meeting

1. **In browser:** Create a new meeting room: `http://localhost:8000/test-recording-002`
2. **Join with 2 participants** (simpler test this time)
3. **Speak for 1 minute**
4. **Leave meeting**

### Step 7.2: Verify Second Recording

```bash
./scripts/list-recordings.sh
```

**Expected Output:** Should show 2 recordings now:
```
Found 2 recording(s):

● room-2025-11-07-10-45-30.mka
  Size: 1.8MB
  Date: 2025-11-07 10:46:45
  Tracks: 2
  Duration: 0:01:05

● room-2025-11-07-10-30-15.mka
  Size: 2.5MB
  Date: 2025-11-07 10:32:15
  Tracks: 3
  Duration: 0:02:15

Total recordings: 2
```

**Verification:**
- ✅ Both recordings present
- ✅ Different filenames (timestamps)
- ✅ Different track counts (2 vs 3)
- ✅ Different durations

---

## Part 8: Test Different Output Formats

### Step 8.1: Extract as FLAC

```bash
./scripts/extract-tracks.sh recordings/room-2025-11-07-10-30-15.mka flac
```

**Expected:** Extraction succeeds, files saved as `.flac`

### Step 8.2: Extract as MP3

```bash
./scripts/extract-tracks.sh recordings/room-2025-11-07-10-30-15.mka mp3
```

**Expected:** Extraction succeeds, files saved as `.mp3`

### Step 8.3: Verify Multiple Extraction Formats

```bash
ls -lh recordings/extracted_*/
```

**Expected:** Multiple directories with different formats:
- `extracted_room-..._wav/` - WAV files
- `extracted_room-..._flac/` - FLAC files
- `extracted_room-..._mp3/` - MP3 files

---

## Part 9: Stress Test (Optional)

### Step 9.1: Test with Maximum Participants

Objective: Verify system handles target load (5-10 participants).

1. **Create meeting:** `http://localhost:8000/stress-test`
2. **Join with 5+ participants** (use multiple devices/browsers)
3. **Monitor system resources:**

```bash
# In another terminal
docker stats
```

Watch CPU and memory usage while meeting is active.

4. **Run meeting for 5 minutes**
5. **End meeting and verify recording**

**Acceptance Criteria:**
- ✅ All participants can join
- ✅ Audio/video quality remains good
- ✅ No crashes or disconnections
- ✅ Recording completes successfully
- ✅ System resources stay below 80% (CPU/memory)

---

## Part 10: Cleanup and Verification

### Step 10.1: Stop the Server

```bash
./scripts/stop-server.sh
```

**Expected Output:**
```
==================================
Stopping Jitsi Multitrack Recording
==================================

ℹ Stopping all services...

Stopping jitsi_jvb ... done
Stopping jitsi_jicofo ... done
Stopping jitsi_web ... done
Stopping jitsi_multitrack_recorder ... done
Stopping jitsi_prosody ... done
Removing jitsi_jvb ... done
...

✓ All services stopped successfully!
```

### Step 10.2: Verify Containers Stopped

```bash
docker-compose ps
```

**Expected Output:** No running containers, or all show "Exit" state.

### Step 10.3: Verify Recordings Persisted

```bash
ls -lh recordings/
```

**Expected:** Recording files still exist (they're stored on host filesystem, not in containers).

### Step 10.4: Restart and Verify

```bash
# Restart
./scripts/start-server.sh

# Wait 10 seconds

# Verify services running
docker-compose ps
```

**Expected:** All services start successfully again.

### Step 10.5: Final Cleanup (Optional)

If you want to clean up completely:

```bash
# Stop services
./scripts/stop-server.sh

# Remove containers and networks
docker-compose down

# Remove Docker images (optional, frees disk space)
docker-compose down --rmi all

# Remove recordings (optional)
rm -rf recordings/*.mka recordings/extracted_*
```

---

## Testing Checklist

Use this checklist to verify all functionality:

### Setup Phase
- [ ] Docker installed and running
- [ ] Docker Compose installed
- [ ] Repository cloned
- [ ] Configuration generated (.env file created)
- [ ] All scripts are executable

### Server Phase
- [ ] All containers start successfully
- [ ] Web interface accessible at http://localhost:8000
- [ ] No errors in service logs
- [ ] Recorder service is listening on port 8989

### Meeting Phase
- [ ] Can create a meeting
- [ ] Browser requests microphone/camera permissions
- [ ] Self-view video works
- [ ] Multiple participants can join
- [ ] Participants can see/hear each other
- [ ] Audio level indicators respond to speech

### Recording Phase
- [ ] Recording starts automatically
- [ ] Recording file created in recordings/ directory
- [ ] File has correct timestamp
- [ ] File size is non-zero
- [ ] Finalize hook executes (.ready file created)

### Extraction Phase
- [ ] Can list recordings with details
- [ ] Track count matches participant count
- [ ] Can extract tracks as WAV
- [ ] Can extract tracks as FLAC
- [ ] Can extract tracks as MP3
- [ ] Each extracted file is non-zero size

### Verification Phase
- [ ] Each track plays correctly
- [ ] Each track contains only one participant's audio
- [ ] No audio mixing between tracks
- [ ] Audio quality is clear
- [ ] Duration matches meeting length

### Multiple Recordings
- [ ] Can conduct multiple sequential meetings
- [ ] Each meeting creates separate recording file
- [ ] All recordings are preserved
- [ ] No file corruption

### Cleanup Phase
- [ ] Can stop server cleanly
- [ ] Recordings persist after stopping
- [ ] Can restart server successfully

---

## Success Criteria

**✅ Test is SUCCESSFUL if:**

1. **All containers start and run** without errors
2. **Web interface loads** at http://localhost:8000
3. **Multiple participants can join** a meeting
4. **Audio and video work** for all participants
5. **Recording file is created** after meeting ends
6. **Recording contains correct number of tracks** (one per participant)
7. **Tracks can be extracted** to separate audio files
8. **Each track contains isolated audio** from one participant only
9. **Audio quality is clear** and intelligible
10. **Multiple meetings create separate recordings** without conflicts

**❌ Test is FAILED if:**

- Any container fails to start
- Web interface doesn't load
- No recording file is created
- Recording file is zero bytes
- Wrong number of tracks (doesn't match participant count)
- Tracks contain mixed audio (multiple voices per track)
- Audio extraction fails
- Audio quality is poor or unintelligible
- Server crashes during meeting

---

## Common Issues and Solutions

### Issue: Port 8000 Already in Use

**Symptom:** Web container fails to start, error about port binding

**Solution:**
```bash
# Find what's using port 8000
sudo netstat -tulpn | grep 8000

# Kill the process or change port in .env
# Edit .env: HTTP_PORT=8080
# Then restart
./scripts/stop-server.sh && ./scripts/start-server.sh
```

### Issue: No Audio in Recording

**Symptom:** Recording file created but tracks are silent

**Solution:**
```bash
# Check JVB logs
./scripts/view-logs.sh jvb | grep -i "multitrack\|recorder"

# Verify JVB can reach recorder
docker-compose exec jvb ping -c 3 recorder

# Check recorder logs
./scripts/view-logs.sh recorder | grep -i "websocket\|connection"

# Restart JVB
docker-compose restart jvb
```

### Issue: Participants Can't Connect

**Symptom:** Meeting loads but participants see connection errors

**Solution:**
```bash
# Check if UDP port 10000 is accessible
sudo ufw allow 10000/udp

# Check JVB logs
./scripts/view-logs.sh jvb

# Verify JVB container is running
docker-compose ps jvb
```

### Issue: Docker Permission Denied

**Symptom:** `permission denied while trying to connect to Docker daemon`

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and log back in, or:
newgrp docker

# Verify
docker ps
```

---

## Report Results

After completing all tests, report the following:

### Test Summary
- **Date/Time:** [timestamp]
- **System:** [OS, Docker version]
- **Result:** [PASS/FAIL]

### Metrics
- Number of test meetings conducted: [X]
- Maximum participants tested: [X]
- Total recordings created: [X]
- Average file size: [X MB]
- Audio quality: [Good/Fair/Poor]

### Issues Encountered
- [List any problems and how they were resolved]

### Recommendations
- [Any suggestions for improvements or concerns]

---

**END OF TESTING INSTRUCTIONS**

You have now completed comprehensive testing of the Jitsi multitrack recording server. If all tests pass, the system is ready for production deployment.
