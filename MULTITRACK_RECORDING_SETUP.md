# Multitrack Recording Setup Guide

**Date**: 2025-11-17
**Status**: ✅ Configured and ready for testing

---

## Critical Discovery

The jitsi-multitrack-recorder **does NOT use the recording infrastructure** (`ENABLE_RECORDING=1`). Instead, it leverages Jitsi's **transcription infrastructure** to trigger audio stream export from JVB.

**Source**: [GitHub Issue #26](https://github.com/jitsi/jitsi-multitrack-recorder/issues/26) - confirmed by project maintainer @bgrozev

---

## How It Works

### Architecture Flow

1. **Client Triggers**: User starts recording in the web UI
2. **RoomMetadata Updated**: Client sets `transcribing.isTranscribingEnabled=true`
3. **Jicofo Processes**: Reads `transcription.url-template` from config
4. **JVB Connects**: JVB opens WebSocket connection to recorder at configured URL
5. **Audio Export**: JVB streams each participant's audio separately via WebSocket
6. **Recording**: Multitrack recorder saves streams as MKA (Matroska Audio) files

---

## Configuration Applied

### 1. Jicofo Configuration

**File**: [Dockerfile.jicofo](Dockerfile.jicofo)

Added transcription URL template that tells Jicofo where to send audio streams:

```dockerfile
# Add transcription configuration for multitrack recorder
RUN echo '\n\
jicofo {\n\
  transcription {\n\
    url-template = "ws://recorder:8989/record/MEETING_ID"\n\
  }\n\
}' >> /defaults/jicofo.conf
```

**Result**: Jicofo's generated config at `/config/jicofo.conf` includes:
```
transcription {
  url-template = "ws://recorder:8989/record/MEETING_ID"
}
```

### 2. Web Frontend Configuration

**File**: [config/web/custom-config.js](config/web/custom-config.js)

Created custom configuration to enable transcription UI and triggers:

```javascript
// Enable transcription (required for multitrack recorder to work)
config.transcription = {
    enabled: true,
    inviteJigasiOnBackendTranscribing: false,  // Don't use Jigasi
    autoTranscribeOnRecord: true
};

config.recording = { enabled: true };
config.fileRecordingsEnabled = true;
config.localRecording = { enabled: false };
```

**Mounted**: Via [docker-compose.yml](docker-compose.yml):
```yaml
volumes:
  - ./config/web/custom-config.js:/usr/share/jitsi-meet/custom-config.js:ro
```

---

## What to Look For in Logs

### When Recording Starts

**Jicofo logs** should show:
```
Setting enableTranscribing=true
Adding connect, url=ws://recorder:8989/record/MEETING_ID
```

**JVB logs** should show:
```
Starting with url=ws://recorder:8989/record/MEETING_ID
Exporter websocket connected
```

**Recorder logs** should show:
```
WebSocket connection accepted
Receiving audio stream for endpoint: <endpoint_id>
```

### Commands to Monitor

```bash
# Watch for transcription events in Jicofo
docker-compose logs -f jicofo | grep -E "(transcri|Transcri|connect)"

# Watch for exporter activity in JVB
docker-compose logs -f jvb | grep -E "(Exporter|export|Starting with url)"

# Watch for WebSocket connections in recorder
docker-compose logs -f recorder | grep -E "(WebSocket|connection|Receiving)"
```

---

## Testing Procedure

### 1. Access the Web Interface

Open browser to: **http://localhost:8000** or **https://localhost:8443**

### 2. Start a Meeting

Create a new meeting with any name (e.g., `test-multitrack-251117`)

### 3. Start Recording

Look for the **recording button** in the UI (should be visible due to `config.recording.enabled=true`)

Click to start recording. This should:
- Set `transcribing.isTranscribingEnabled=true` in RoomMetadata
- Trigger Jicofo to send connect message to JVB
- Trigger JVB to connect to recorder via WebSocket

### 4. Verify in Logs

While the meeting is active and recording:

```bash
# Check for transcription enablement
docker-compose logs jicofo | tail -50 | grep -i transcri

# Check for JVB exporter starting
docker-compose logs jvb | tail -50 | grep -i export

# Check for recorder connections
docker-compose logs recorder | tail -20
```

### 5. Check Recordings Directory

After stopping recording:

```bash
ls -lh recordings/
```

Should contain `.mka` files (Matroska Audio) with separate tracks per participant.

---

## Troubleshooting

### Issue: No "Setting enableTranscribing" in Jicofo logs

**Possible Causes**:
1. Frontend `custom-config.js` not loaded
2. Recording button not clicked or not visible
3. Client not sending transcription metadata update

**Solution**: Verify custom-config.js is mounted and check browser console for errors

### Issue: Jicofo says "Setting enableTranscribing" but no "Adding connect"

**Possible Causes**:
1. Transcription URL template not in Jicofo config
2. Configuration syntax error

**Solution**: Verify config with:
```bash
docker-compose exec -T jicofo cat /config/jicofo.conf | grep -A5 transcription
```

### Issue: JVB doesn't show "Starting with url"

**Possible Causes**:
1. JVB not built from master (exporter code only in master)
2. JVB not receiving connect message from Jicofo
3. Exporter code not present in custom JVB build

**Solution**: Rebuild JVB from master branch and verify exporter classes exist:
```bash
cd ~/Work/guess-class/jitsi-videobridge/jvb/target
unzip -q jitsi-videobridge-2.3-SNAPSHOT-archive.zip
find jitsi-videobridge-2.3-SNAPSHOT -name "*Exporter*"
```

### Issue: Recorder shows no WebSocket connections

**Possible Causes**:
1. Network connectivity between JVB and recorder
2. Recorder not listening on correct port
3. JVB unable to resolve "recorder" hostname

**Solution**: Verify recorder is running and accessible:
```bash
docker-compose ps recorder
docker-compose logs recorder | grep "Starting"
docker-compose exec -T jvb ping -c 2 recorder
```

---

## Differences from Jibri Recording

| Feature | Multitrack Recorder | Jibri |
|---------|-------------------|-------|
| **Infrastructure Used** | Transcription | Recording |
| **Trigger** | `transcription.url-template` | `ENABLE_RECORDING=1` |
| **Output Format** | MKA (separate tracks) | MP4 (mixed A/V) |
| **Documentation** | Minimal/Experimental | Well-documented |
| **Production Ready** | ❌ Experimental | ✅ Stable |
| **Setup Complexity** | High | Medium |
| **Audio Separation** | Native | Requires post-processing |

---

## Environment Variables (Mostly Irrelevant)

These variables are **NOT used** by multitrack recorder:

- ❌ `ENABLE_RECORDING` - Only affects Jibri-style recording
- ❌ `ENABLE_AUTO_RECORDING` - Not supported
- ❌ `XMPP_RECORDER_DOMAIN` - Not needed (no XMPP component)
- ❌ `JIBRI_RECORDER_PASSWORD` - Not needed

These variables **ARE used** by multitrack recorder:

- ✅ `RECORDING_DIR=/recordings` - Where to save MKA files
- ✅ `FINALIZE_SCRIPT` - Script to run after recording completes

---

## Files Modified/Created

### Configuration Files
- ✅ [Dockerfile.jicofo](Dockerfile.jicofo) - Added transcription URL template
- ✅ [config/web/custom-config.js](config/web/custom-config.js) - NEW: Frontend transcription config
- ✅ [docker-compose.yml](docker-compose.yml) - Added custom-config.js mount
- ✅ [.gitignore](.gitignore) - Whitelist custom-config.js

### Documentation
- ✅ [MULTITRACK_RECORDING_SETUP.md](MULTITRACK_RECORDING_SETUP.md) - This file

---

## Next Steps

1. **Test the setup** by creating a meeting and starting recording
2. **Monitor logs** for transcription events and WebSocket connections
3. **Verify recordings** are created in `./recordings/` directory
4. **If it doesn't work**: Consider switching to Jibri (stable, production-ready alternative)

---

## References

- **Project Repository**: https://github.com/jitsi/jitsi-multitrack-recorder
- **Key Issue with Setup Details**: https://github.com/jitsi/jitsi-multitrack-recorder/issues/26
- **Configuration Clarification**: https://github.com/jitsi/jitsi-multitrack-recorder/issues/29
- **Docker Image**: hub.docker.com/r/jitsi/jitsi-multitrack-recorder

---

**Status**: Ready for testing ✅

The transcription-based configuration is now in place. Create a meeting at http://localhost:8000 and test the recording functionality!
