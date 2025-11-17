# Jitsi Multitrack Recording Server

A self-hosted Jitsi Meet server with multitrack audio recording capability. Each participant's audio is recorded as a separate track, eliminating the need for diarization in post-processing.

## 🎯 Features

- **Multitrack Audio Recording**: Each participant recorded on a separate audio track
- **Automatic Recording**: Optional auto-start when meetings begin
- **Docker-Based**: Easy deployment with Docker Compose
- **Localhost Testing**: Test locally before production deployment
- **No E2EE Overhead**: Optimized for recording (E2EE disabled)
- **Flexible Scale**: Supports 1 meeting with up to 10 participants
- **Post-Processing Ready**: Includes scripts for extracting individual audio files

## 📋 Prerequisites

- **Docker** (version 20.10+)
- **Docker Compose** (version 1.29+)
- **Git**
- **8GB RAM** minimum
- **4 CPU cores** recommended
- **OpenSSL** (for password generation)
- **FFmpeg** (optional, for audio extraction)

### Installing Prerequisites

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose git openssl ffmpeg
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

**macOS:**
```bash
brew install docker docker-compose git openssl ffmpeg
```

**Verify Installation:**
```bash
docker --version
docker-compose --version
```

## ⚠️ IMPORTANT: First Time Setup

**This repository requires building custom JVB and Jicofo components before first use.**

The build artifacts (`docker/jvb/` and `docker/jicofo/`) are **NOT** included in the repository due to size. You must build them yourself following the instructions in [02_SETUP_CUSTOM_CONTAINERS_HOWTO.md](02_SETUP_CUSTOM_CONTAINERS_HOWTO.md).

**Quick setup summary**:
1. Clone required source repos: `jitsi-videobridge` and `jicofo`
2. Build with Maven: `mvn clean package -DskipTests`
3. Extract and copy artifacts to `docker/jvb/` and `docker/jicofo/`
4. Generate passwords with `./scripts/generate-passwords.sh`
5. Build Docker images: `docker-compose build`
6. Start: `docker-compose up -d`

See [CRITICAL_FIXES.md](CRITICAL_FIXES.md) for detailed setup checklist.

---

## 🚀 Quick Start (After Build Setup)

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/jitsi-multitrack-recording.git
cd jitsi-multitrack-recording
```

### 2. Build Custom Components

**REQUIRED FOR FIRST TIME SETUP** - See [02_SETUP_CUSTOM_CONTAINERS_HOWTO.md](02_SETUP_CUSTOM_CONTAINERS_HOWTO.md)

```bash
# Summary (full instructions in link above):
# 1. Clone jitsi-videobridge and jicofo repos
# 2. Build with Maven
# 3. Extract and copy build artifacts
```

### 3. Generate Configuration

Run the setup script to generate secure passwords and create the `.env` file:

```bash
./scripts/generate-passwords.sh
```

You'll be prompted to:
- Set your PUBLIC_URL (default: `localhost:8443` for HTTPS, `localhost:8000` for HTTP)
- Enable/disable automatic recording

### 4. Build and Start the Server

```bash
# Build custom Docker images
docker-compose build

# Start all services
docker-compose up -d
```

The server will start all Jitsi components:
- Jitsi Meet (web interface)
- Prosody (XMPP server)
- Jicofo (conference focus)
- Jitsi Videobridge (media router)
- Multitrack Recorder

### 4. Access Jitsi Meet

Open your browser and navigate to:
```
http://localhost:8000
```

Create a room by entering a name and clicking "Go".

### 5. Start a Meeting

- Enter a room name
- Allow microphone/camera permissions
- Invite participants by sharing the URL
- Recording starts automatically (if enabled) or use in-meeting controls

## 📁 Directory Structure

```
jitsi-multitrack-recording/
├── config/                    # Configuration files
│   ├── web/                  # Jitsi Meet web config
│   ├── prosody/              # XMPP server config
│   ├── jicofo/               # Conference focus config
│   ├── jvb/                  # Videobridge config
│   │   └── sip-communicator.properties  # JVB multitrack config
│   └── recorder/             # Recorder config
├── recordings/               # Recorded meetings (MKA files)
├── scripts/                  # Management scripts
│   ├── generate-passwords.sh # Setup script
│   ├── start-server.sh       # Start all services
│   ├── stop-server.sh        # Stop all services
│   ├── view-logs.sh          # View service logs
│   ├── list-recordings.sh    # List recordings
│   ├── extract-tracks.sh     # Extract individual tracks
│   └── finalize-recording.sh # Post-processing hook
├── docs/                     # Additional documentation
├── docker-compose.yml        # Docker services definition
├── .env.example              # Environment template
└── README.md                 # This file
```

## 🎛️ Configuration

### Environment Variables (.env)

Key configuration options in `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `PUBLIC_URL` | `localhost:8000` | Public URL (without http://) |
| `HTTP_PORT` | `8000` | HTTP port for web interface |
| `HTTPS_PORT` | `8443` | HTTPS port (if SSL enabled) |
| `JVB_PORT` | `10000` | UDP port for media (must be open) |
| `ENABLE_AUTO_RECORDING` | `1` | Auto-start recording (1=yes, 0=no) |
| `ENABLE_AUTH` | `0` | Require authentication (0=public) |
| `XMPP_DOMAIN` | `meet.jitsi` | Internal XMPP domain |
| `TZ` | `UTC` | Timezone |

### Multitrack Recording Configuration

Located in `config/jvb/sip-communicator.properties`:

```properties
org.jitsi.videobridge.ENABLE_MULTITRACK_RECORDER=true
org.jitsi.videobridge.MULTITRACK_RECORDER_ENDPOINT=ws://recorder:8989/record
```

## 🛠️ Management Scripts

### Start Server
```bash
./scripts/start-server.sh
```

### Stop Server
```bash
./scripts/stop-server.sh
```

### View Logs
```bash
# All services
./scripts/view-logs.sh all

# Specific service
./scripts/view-logs.sh recorder
./scripts/view-logs.sh jvb
./scripts/view-logs.sh web
```

### List Recordings
```bash
./scripts/list-recordings.sh
```

### Extract Individual Tracks
```bash
# Extract as WAV (default)
./scripts/extract-tracks.sh recordings/room-2025-01-15-10-30-00.mka

# Extract as FLAC
./scripts/extract-tracks.sh recordings/room-2025-01-15-10-30-00.mka flac

# Extract as MP3
./scripts/extract-tracks.sh recordings/room-2025-01-15-10-30-00.mka mp3
```

## 🎵 Working with Recordings

### Recording Format

Recordings are saved as `.mka` (Matroska Audio) files with multiple audio tracks:
```
recordings/
└── room-2025-01-15-10-30-00.mka
    ├── Track 0: Participant 1 audio
    ├── Track 1: Participant 2 audio
    ├── Track 2: Participant 3 audio
    └── ...
```

### Extracting Tracks

Use the extraction script to split the multitrack file:

```bash
./scripts/extract-tracks.sh recordings/room-2025-01-15-10-30-00.mka wav
```

Output:
```
recordings/extracted_room-2025-01-15-10-30-00/
├── track_0.wav
├── track_1.wav
├── track_2.wav
└── ...
```

### Identifying Participants

**Note**: By default, tracks are numbered (0, 1, 2, etc.) and not named. The mapping between track numbers and participant names requires additional implementation.

To identify participants, you have these options:
1. Note participant join order (tracks are created in join order)
2. Implement custom tracking (requires extending the recorder)
3. Use audio analysis to match voices post-meeting

## 🔧 Troubleshooting

### Server won't start

**Check Docker is running:**
```bash
docker info
```

**Check if ports are available:**
```bash
sudo netstat -tulpn | grep -E '8000|8443|10000'
```

**View service status:**
```bash
docker-compose ps
```

### No recordings created

**Check recorder logs:**
```bash
./scripts/view-logs.sh recorder
```

**Verify recorder is running:**
```bash
docker-compose ps recorder
```

**Check recordings directory permissions:**
```bash
ls -la recordings/
chmod -R 755 recordings/
```

### Audio not recording / Empty tracks

**Check JVB configuration:**
```bash
cat config/jvb/sip-communicator.properties | grep MULTITRACK
```

**Verify JVB can reach recorder:**
```bash
docker-compose exec jvb ping -c 3 recorder
```

**Check JVB logs:**
```bash
./scripts/view-logs.sh jvb | grep -i multitrack
```

### Participants can't connect

**Check firewall allows UDP 10000:**
```bash
sudo ufw status
sudo ufw allow 10000/udp
```

**Verify DOCKER_HOST_ADDRESS (if on remote server):**
Edit `.env` and set:
```
DOCKER_HOST_ADDRESS=your.server.ip.address
```

Then restart:
```bash
./scripts/stop-server.sh
./scripts/start-server.sh
```

## 🐳 Docker Commands

### View running containers
```bash
docker-compose ps
```

### Restart a specific service
```bash
docker-compose restart recorder
docker-compose restart jvb
```

### View resource usage
```bash
docker stats
```

### Clean up (stop and remove containers)
```bash
docker-compose down
```

### Clean up everything (including volumes)
```bash
docker-compose down -v
```

## 📊 Performance & Scaling

### Current Configuration
- **Meetings**: 1 concurrent meeting
- **Participants**: Up to 10 per meeting
- **Resources**: 8GB RAM, 4 CPU cores

### Scaling Up

To handle more participants or meetings:

1. **Increase server resources** (RAM, CPU)
2. **Tune JVB settings** in `config/jvb/sip-communicator.properties`
3. **Add more JVB instances** (requires cascade configuration)
4. **Monitor resource usage**: `docker stats`

## 🔐 Security Considerations

⚠️ **Important Security Notes:**

- **E2EE Disabled**: Required for server-side recording
- **Public Access**: Default config allows anyone with link to join
- **No Authentication**: AUTH disabled by default
- **Localhost Only**: Default setup is HTTP-only on localhost

### For Production Use:

1. **Enable HTTPS**: Set up SSL certificates (Let's Encrypt)
2. **Enable Authentication**: Set `ENABLE_AUTH=1` in `.env`
3. **Configure Firewall**: Only expose necessary ports
4. **Use Strong Passwords**: Run `./scripts/generate-passwords.sh` again
5. **Regular Updates**: Keep Docker images updated

## 🌐 Production Deployment

### Prerequisites for Production

1. **Domain Name**: e.g., `meet.yourcompany.com`
2. **SSL Certificate**: Let's Encrypt or commercial
3. **Public Server**: With open ports 80, 443, 10000/UDP
4. **DNS Configuration**: A record pointing to server IP

### Production Configuration

Edit `.env`:
```bash
PUBLIC_URL=https://meet.yourcompany.com
ENABLE_LETSENCRYPT=1
ENABLE_HTTP_REDIRECT=1
DISABLE_HTTPS=0
ENABLE_AUTH=1  # Optional: require authentication
```

Restart services:
```bash
./scripts/stop-server.sh
./scripts/start-server.sh
```

## 📚 Additional Documentation

- [Jitsi Meet Handbook](https://jitsi.github.io/handbook/)
- [Jitsi Videobridge](https://github.com/jitsi/jitsi-videobridge)
- [Multitrack Recorder](https://github.com/jitsi/jitsi-multitrack-recorder)
- [Docker Documentation](https://docs.docker.com/)

## 🤝 Contributing

This is an internal project. For issues or improvements, contact the development team.

## 📄 License

See [LICENSE](LICENSE) file for details.

## 💡 Tips & Best Practices

### Recording Best Practices
- Test recordings with 2-3 participants first
- Ensure all participants have stable internet connections
- Use wired connections when possible (lower latency)
- Encourage participants to use headphones (reduces echo)

### System Maintenance
- Regularly clean up old recordings to free disk space
- Monitor disk usage: `df -h`
- Check Docker logs periodically for errors
- Restart services weekly for stability: `docker-compose restart`

### Audio Quality
- Encourage participants to use external microphones
- Quiet environment reduces background noise
- Recording quality depends on participant's microphone and internet quality
- Each track is recorded independently (no mixing)

## 🆘 Getting Help

If you encounter issues:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Review logs: `./scripts/view-logs.sh all`
3. Check the [docs/](docs/) folder for additional guides
4. Contact the development team with:
   - Error messages from logs
   - Steps to reproduce the issue
   - Your environment (OS, Docker version, etc.)

---

**Ready to start?** Run `./scripts/generate-passwords.sh` and begin testing!
