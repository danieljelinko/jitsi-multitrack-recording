# Testing Guide - Jitsi Multitrack Recording

This guide will help you test the Jitsi multitrack recording setup on localhost before deploying to production.

## Prerequisites Check

Before starting, ensure you have:

```bash
# Check Docker
docker --version
# Should show: Docker version 20.10 or higher

# Check Docker Compose
docker-compose --version
# Should show: docker-compose version 1.29 or higher

# Check Docker is running
docker info
# Should show Docker system information

# Check OpenSSL (for password generation)
openssl version
# Should show OpenSSL version

# Optional: Check FFmpeg (for audio extraction)
ffmpeg -version
# Should show FFmpeg version
```

## Step-by-Step Testing

### Phase 1: Initial Setup

#### 1.1 Clone and Navigate
```bash
git clone https://github.com/your-org/jitsi-multitrack-recording.git
cd jitsi-multitrack-recording
```

#### 1.2 Generate Configuration
```bash
./scripts/generate-passwords.sh
```

**Expected Output:**
- Script prompts for PUBLIC_URL (press Enter for default: `http://localhost:8000`)
- Script prompts for auto-recording (yes/no)
- Script creates `.env` file with random passwords
- Success message displayed

**Verify:**
```bash
ls -la .env
cat .env | grep -v "^#" | grep -v "^$"
```

You should see your configuration with generated passwords.

#### 1.3 Start Services
```bash
./scripts/start-server.sh
```

**Expected Output:**
- Docker pulls images (first time only, takes 5-10 minutes)
- Services start successfully
- Status shows all containers running

**Verify:**
```bash
docker-compose ps
```

Expected status for all services:
```
Name                    State    Ports
jitsi_web               Up       0.0.0.0:8000->80/tcp
jitsi_prosody           Up       5222/tcp, 5280/tcp, 5347/tcp
jitsi_jicofo            Up
jitsi_jvb               Up       0.0.0.0:10000->10000/udp
jitsi_multitrack_recorder Up     0.0.0.0:8989->8989/tcp
```

### Phase 2: Basic Functionality Testing

#### 2.1 Access Web Interface

Open your browser and navigate to:
```
http://localhost:8000
```

**Expected:**
- Jitsi Meet interface loads
- No certificate warnings (we're using HTTP)
- "Start new meeting" or room name input visible

**Troubleshooting:**
- If page doesn't load: Check `./scripts/view-logs.sh web`
- If services aren't running: Check `docker-compose ps`

#### 2.2 Create a Test Meeting

1. Enter a room name (e.g., "test-room")
2. Click "Go" or press Enter
3. Allow microphone and camera permissions when prompted

**Expected:**
- You join the meeting
- You can see yourself on video
- Audio meter shows your microphone is working

#### 2.3 Test with Multiple Participants

**Option A: Same Computer (Easy)**
Open multiple browser tabs/windows:
1. Tab 1: Already in the meeting
2. Tab 2: Open `http://localhost:8000/test-room` in incognito/private mode
3. Tab 3: Open same URL in a different browser

**Option B: Multiple Devices (Recommended)**
1. Find your computer's local IP address:
   ```bash
   # Linux/Mac
   ifconfig | grep "inet " | grep -v 127.0.0.1
   # Or
   ip addr show | grep "inet " | grep -v 127.0.0.1
   ```

2. On another device (phone, tablet, another computer) on the same network:
   - Open browser and navigate to: `http://YOUR_LOCAL_IP:8000/test-room`
   - Example: `http://192.168.1.100:8000/test-room`

**Expected:**
- Multiple participants can join
- Everyone can see and hear each other
- Video and audio working smoothly

### Phase 3: Recording Testing

#### 3.1 Verify Recorder is Running

```bash
./scripts/view-logs.sh recorder
```

**Expected logs:**
- Recorder service started
- WebSocket server listening on port 8989
- No error messages

#### 3.2 Check Auto-Recording Status

```bash
grep "ENABLE_AUTO_RECORDING" .env
```

If `ENABLE_AUTO_RECORDING=1`:
- Recording starts automatically when meeting begins
- No manual action needed

If `ENABLE_AUTO_RECORDING=0`:
- Must start recording manually from meeting interface
- Look for recording button in Jitsi UI

#### 3.3 Conduct Test Recording

1. **Start a meeting** with 2-3 participants (real or simulated)
2. **Speak in turn** for at least 30 seconds each:
   - Participant 1: "This is participant one testing the recording system"
   - Participant 2: "This is participant two, testing multitrack recording"
   - Participant 3: "Participant three here, testing audio quality"
3. **Wait at least 2 minutes** (ensures recording has content)
4. **End the meeting** (all participants leave)

#### 3.4 Verify Recording Created

Wait 10-30 seconds after meeting ends, then:

```bash
./scripts/list-recordings.sh
```

**Expected output:**
```
Found 1 recording(s):

● room-2025-01-15-10-30-00.mka
  Size: 2.5MB
  Date: 2025-01-15 10:32:15
  Tracks: 3
  Duration: 0:02:15
```

**Verify recording file exists:**
```bash
ls -lh recordings/
```

You should see `.mka` files with timestamps.

### Phase 4: Track Extraction Testing

#### 4.1 Extract Audio Tracks

```bash
# Extract as WAV
./scripts/extract-tracks.sh recordings/room-*.mka wav
```

**Expected output:**
```
Extracting Audio Tracks
==================================
Input file: recordings/room-2025-01-15-10-30-00.mka
Output format: wav
Output directory: recordings/extracted_room-2025-01-15-10-30-00

Found 3 audio track(s)

Extracting track 1/3...
✓ Saved: track_0.wav (5.2MB)

Extracting track 2/3...
✓ Saved: track_1.wav (5.1MB)

Extracting track 3/3...
✓ Saved: track_2.wav (4.9MB)

Extraction complete!
```

#### 4.2 Verify Extracted Files

```bash
ls -lh recordings/extracted_*/
```

**Expected:**
- One `.wav` file per participant
- File sizes reasonable (5-10MB per minute of audio)
- All files present

#### 4.3 Test Audio Playback

Play each track to verify:

**Linux:**
```bash
# Install if needed: sudo apt-get install vlc
vlc recordings/extracted_*/track_0.wav
```

**macOS:**
```bash
afplay recordings/extracted_*/track_0.wav
```

**Windows (WSL):**
```bash
# Use Windows media player
explorer.exe recordings/extracted_*
```

**Verify:**
- Each track plays correctly
- You can hear the specific participant on each track
- No mixing of participants (each track is isolated)
- Audio quality is clear

### Phase 5: Load Testing

#### 5.1 Test with Maximum Participants

1. Join a meeting with 5-10 participants (your target max)
2. All participants turn on audio and video
3. Let meeting run for 5-10 minutes
4. Monitor system resources:

```bash
# In another terminal
docker stats

# Watch CPU and memory usage
# JVB and recorder should handle load
```

**Expected:**
- System remains responsive
- No audio/video dropouts
- Recording completes successfully

#### 5.2 Multiple Sequential Meetings

1. **Meeting 1**: 3 participants, 2 minutes
2. End meeting, wait 30 seconds
3. **Meeting 2**: 4 participants, 3 minutes
4. End meeting, wait 30 seconds
5. **Meeting 3**: 2 participants, 2 minutes

**Verify:**
```bash
./scripts/list-recordings.sh
```

**Expected:**
- 3 separate recording files
- All files complete and playable
- No file corruption or missing data

## Common Issues & Solutions

### Issue: Services Won't Start

**Symptom:**
```bash
docker-compose ps
# Shows services with "Exit 1" or "Restarting"
```

**Solution:**
```bash
# Check logs for specific service
./scripts/view-logs.sh prosody
./scripts/view-logs.sh jvb
./scripts/view-logs.sh recorder

# Common fixes:
# 1. Port already in use
sudo netstat -tulpn | grep -E '8000|10000|8989'
# Kill process using those ports or change ports in .env

# 2. Permissions issue
chmod -R 755 config recordings

# 3. Restart services
./scripts/stop-server.sh
./scripts/start-server.sh
```

### Issue: No Audio in Recordings

**Symptom:**
Recording file created but tracks are empty or silent.

**Solutions:**

1. **Check JVB configuration:**
```bash
cat config/jvb/sip-communicator.properties | grep MULTITRACK
```
Should show:
```
org.jitsi.videobridge.ENABLE_MULTITRACK_RECORDER=true
org.jitsi.videobridge.MULTITRACK_RECORDER_ENDPOINT=ws://recorder:8989/record
```

2. **Verify JVB can reach recorder:**
```bash
docker-compose exec jvb ping -c 3 recorder
```
Should show successful pings.

3. **Check recorder is receiving connections:**
```bash
./scripts/view-logs.sh recorder | grep -i "connection\|websocket"
```

4. **Restart JVB:**
```bash
docker-compose restart jvb
```

### Issue: Browser Can't Access Localhost:8000

**Symptom:**
Browser shows "Can't connect" or "ERR_CONNECTION_REFUSED"

**Solutions:**

1. **Verify web service is running:**
```bash
docker-compose ps web
```

2. **Check port binding:**
```bash
docker port jitsi_web
# Should show: 80/tcp -> 0.0.0.0:8000
```

3. **Test with curl:**
```bash
curl -I http://localhost:8000
# Should show HTTP 200 OK
```

4. **Check firewall:**
```bash
# Linux
sudo ufw status
sudo ufw allow 8000/tcp

# macOS
# Check System Preferences > Security & Privacy > Firewall
```

### Issue: Participants Can't Connect from Other Devices

**Symptom:**
Works on localhost but not from other devices on network.

**Solutions:**

1. **Update PUBLIC_URL in .env:**
```bash
# Find your local IP
ip addr show | grep "inet " | grep -v 127.0.0.1
# Example output: 192.168.1.100

# Edit .env
PUBLIC_URL=http://192.168.1.100:8000
```

2. **Restart services:**
```bash
./scripts/stop-server.sh
./scripts/start-server.sh
```

3. **Check firewall allows UDP 10000:**
```bash
sudo ufw allow 10000/udp
```

### Issue: Recording Stops Prematurely

**Symptom:**
Recording file exists but duration is shorter than meeting.

**Solutions:**

1. **Check disk space:**
```bash
df -h
```

2. **Check recorder logs for errors:**
```bash
./scripts/view-logs.sh recorder | tail -50
```

3. **Increase system resources** if CPU/memory maxed out:
```bash
docker stats
```

## Testing Checklist

Use this checklist to verify your setup:

- [ ] Docker and Docker Compose installed
- [ ] Configuration generated (`.env` file exists)
- [ ] All services start successfully
- [ ] Web interface accessible at `http://localhost:8000`
- [ ] Can create a meeting
- [ ] Microphone and camera work
- [ ] Multiple participants can join
- [ ] Audio and video quality acceptable
- [ ] Recording starts (auto or manual)
- [ ] Recording file created in `recordings/` folder
- [ ] Recording contains correct number of tracks
- [ ] Can extract tracks to separate audio files
- [ ] Extracted audio files play correctly
- [ ] Each track contains isolated participant audio
- [ ] System handles max participant count (5-10)
- [ ] Multiple sequential meetings work correctly
- [ ] Logs show no critical errors

## Next Steps

Once all tests pass:

1. **Document any issues** you encountered and solutions
2. **Test with real users** in your environment
3. **Set up monitoring** for production use
4. **Plan deployment** to production server
5. **Configure backups** for recordings directory

## Performance Benchmarks

Expected performance on test system:

| Metric | Target | Acceptable |
|--------|--------|------------|
| Meeting join time | < 5 seconds | < 10 seconds |
| Audio latency | < 200ms | < 500ms |
| Video framerate | 30fps | 20fps |
| Recording start delay | < 5 seconds | < 15 seconds |
| Track extraction speed | 1x realtime | 0.5x realtime |
| CPU usage (5 participants) | < 50% | < 80% |
| Memory usage | < 4GB | < 6GB |

If your performance falls below "Acceptable", consider:
- Upgrading server resources
- Reducing video quality/resolution
- Disabling video (audio-only meetings)
- Optimizing Docker container settings

---

**Happy testing!** If you encounter issues not covered here, check the main [README](../README.md) or contact the development team.
