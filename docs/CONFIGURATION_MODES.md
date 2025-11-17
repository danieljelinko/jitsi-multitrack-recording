# Configuration Modes - Jitsi Multitrack Recording

This document explains the two configuration modes available for running Jitsi: **Localhost** (for testing) and **Production** (for deployment).

## Overview

The system now supports two distinct configuration modes to avoid connectivity issues:

- **Localhost Mode**: For local testing without NAT/STUN complications
- **Production Mode**: For deployment on a public server with proper NAT traversal

## Files Structure

```
jitsi-multitrack-recording/
├── docker-compose.yml              # Base configuration
├── docker-compose.localhost.yml    # Localhost overrides
├── docker-compose.production.yml   # Production overrides
├── .env.localhost                  # Localhost environment template
├── .env.production                 # Production environment template
└── scripts/
    ├── start-localhost.sh          # Start in localhost mode
    └── start-production.sh         # Start in production mode (TBD)
```

## Localhost Mode

### Purpose
For testing on your local machine (`localhost:8000`) without external network access.

### Key Features
- Disables STUN servers (prevents external IP discovery)
- Forces `127.0.0.1` for media connectivity
- Disables TCP harvester for simplicity
- Uses HTTP (no SSL)
- Port 8000 for web interface

### Usage

1. **Generate configuration** (first time only):
   ```bash
   ./scripts/generate-passwords.sh
   # OR copy the template:
   cp .env.localhost .env
   # Then generate passwords:
   ./scripts/generate-passwords.sh
   ```

2. **Start the server**:
   ```bash
   ./scripts/start-localhost.sh
   ```

3. **Access Jitsi**:
   ```
   http://localhost:8000
   ```

4. **Stop the server**:
   ```bash
   docker-compose down
   ```

### Configuration Details

The localhost mode applies these settings via `docker-compose.localhost.yml`:

```yaml
services:
  jvb:
    environment:
      - JVB_STUN_SERVERS=                    # Disable STUN
      - DOCKER_HOST_ADDRESS=127.0.0.1        # Force localhost
      - JVB_TCP_HARVESTER_DISABLED=true      # Disable TCP fallback
```

And in `.env`:
```bash
PUBLIC_URL=http://localhost:8000
DOCKER_HOST_ADDRESS=127.0.0.1
JVB_STUN_SERVERS=
JVB_TCP_HARVESTER_DISABLED=true
DISABLE_HTTPS=1
```

### Testing Checklist

When testing in localhost mode:

- [ ] Can access http://localhost:8000
- [ ] Can create a meeting room
- [ ] Can join with audio/video
- [ ] Can join with multiple browser tabs (incognito)
- [ ] Audio/video works between participants
- [ ] No disconnections occur
- [ ] Recording file is created after meeting ends

### Known Issues

1. **STUN still runs**: Even with `JVB_STUN_SERVERS=`, Jitsi uses fallback STUN servers from its default config. However, the static mapping to `127.0.0.1` takes priority, so this should not cause issues.

2. **Docker IP vs Localhost**: JVB runs inside Docker with IP `172.19.0.5`, but we map it to `127.0.0.1` for browser access.

## Production Mode

### Purpose
For deployment on a public server accessible from the internet.

### Key Features
- Enables STUN servers for NAT traversal
- Uses your server's public IP
- Enables HTTPS with Let's Encrypt
- Uses standard ports (80/443)
- Enables TCP fallback for better connectivity

### Usage

1. **Prerequisites**:
   - Public server with static IP
   - Domain name pointing to your server (e.g., `meet.yourdomain.com`)
   - Ports 80, 443, 10000/UDP open in firewall

2. **Generate configuration**:
   ```bash
   cp .env.production .env
   nano .env  # Edit PUBLIC_URL and DOCKER_HOST_ADDRESS
   ./scripts/generate-passwords.sh
   ```

3. **Start the server**:
   ```bash
   ./scripts/start-production.sh  # Coming soon
   # OR manually:
   docker-compose -f docker-compose.yml -f docker-compose.production.yml up -d
   ```

4. **Access Jitsi**:
   ```
   https://meet.yourdomain.com
   ```

### Configuration Details

The production mode applies these settings via `docker-compose.production.yml`:

```yaml
services:
  web:
    ports:
      - '80:80'
      - '443:443'
    environment:
      - DISABLE_HTTPS=0
      - ENABLE_LETSENCRYPT=1
      - ENABLE_HTTP_REDIRECT=1

  jvb:
    environment:
      - JVB_STUN_SERVERS=meet-jit-si-turnrelay.jitsi.net:443
```

And in `.env`:
```bash
PUBLIC_URL=https://meet.yourdomain.com
DOCKER_HOST_ADDRESS=203.0.113.10  # Your server's public IP
JVB_STUN_SERVERS=meet-jit-si-turnrelay.jitsi.net:443
JVB_TCP_HARVESTER_DISABLED=false
DISABLE_HTTPS=0
ENABLE_LETSENCRYPT=1
```

### Production Checklist

Before deploying to production:

- [ ] Domain DNS points to server IP
- [ ] Firewall allows ports 80, 443, 10000/UDP
- [ ] SSL certificate configured (Let's Encrypt)
- [ ] PUBLIC_URL set to `https://your-domain.com`
- [ ] DOCKER_HOST_ADDRESS set to server's public IP
- [ ] Strong passwords generated
- [ ] Consider enabling authentication (`ENABLE_AUTH=1`)
- [ ] Test from external network
- [ ] Recording permissions configured
- [ ] Backups configured

## Troubleshooting

### Localhost Mode Issues

#### Can't join meeting / immediate disconnection

**Symptom**: You can create a room but get disconnected immediately when trying to join.

**Cause**: JVB is advertising the wrong IP address (external IP instead of localhost).

**Solution**:
1. Check JVB logs:
   ```bash
   docker-compose logs jvb | grep -E "Discovered|Mapping"
   ```

2. You should see:
   ```
   StaticMappingCandidateHarvester(face=172.19.0.5:9/udp, mask=127.0.0.1:9/udp)
   ```

3. Verify `.env` has:
   ```bash
   DOCKER_HOST_ADDRESS=127.0.0.1
   ```

4. Restart:
   ```bash
   docker-compose down
   ./scripts/start-localhost.sh
   ```

#### Blank screen at localhost:8000

**Cause**: JVB container is crashing (see main troubleshooting guide).

**Solution**: See [README.md](../README.md#-troubleshooting) section on blank screens.

### Production Mode Issues

#### Participants can't connect from external network

**Cause**: Firewall blocking UDP port 10000.

**Solution**:
```bash
sudo ufw allow 10000/udp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

#### SSL certificate errors

**Cause**: Let's Encrypt requires domain to point to server.

**Solution**: Ensure DNS is configured correctly before starting the server.

## Switching Between Modes

### From Localhost to Production

1. Stop localhost server:
   ```bash
   docker-compose down
   ```

2. Backup your localhost config:
   ```bash
   cp .env .env.localhost.backup
   ```

3. Copy production template:
   ```bash
   cp .env.production .env
   ```

4. Edit for your domain:
   ```bash
   nano .env  # Update PUBLIC_URL and DOCKER_HOST_ADDRESS
   ```

5. Start in production mode:
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.production.yml up -d
   ```

### From Production to Localhost

1. Stop production server:
   ```bash
   docker-compose down
   ```

2. Restore localhost config:
   ```bash
   cp .env.localhost .env
   ```

3. Start in localhost mode:
   ```bash
   ./scripts/start-localhost.sh
   ```

## Environment Variable Reference

### Common Variables

| Variable | Localhost | Production | Description |
|----------|-----------|------------|-------------|
| `PUBLIC_URL` | `http://localhost:8000` | `https://meet.domain.com` | Public access URL |
| `HTTP_PORT` | `8000` | `80` | HTTP port |
| `HTTPS_PORT` | `8443` | `443` | HTTPS port |
| `ENABLE_AUTH` | `0` | `0` or `1` | Require authentication |
| `ENABLE_AUTO_RECORDING` | `1` | `1` | Auto-start recording |

### Network Variables

| Variable | Localhost | Production | Description |
|----------|-----------|------------|-------------|
| `DOCKER_HOST_ADDRESS` | `127.0.0.1` | Server public IP | JVB advertised address |
| `JVB_STUN_SERVERS` | Empty | `meet-jit-si-turnrelay.jitsi.net:443` | STUN servers for NAT |
| `JVB_TCP_HARVESTER_DISABLED` | `true` | `false` | Disable TCP fallback |

### Security Variables

| Variable | Localhost | Production | Description |
|----------|-----------|------------|-------------|
| `DISABLE_HTTPS` | `1` | `0` | Disable HTTPS |
| `ENABLE_LETSENCRYPT` | `0` | `1` | Auto SSL certificates |
| `ENABLE_HTTP_REDIRECT` | `0` | `1` | Redirect HTTP to HTTPS |

## Best Practices

### For Development/Testing

1. Always use **localhost mode** when testing locally
2. Use incognito/private windows for multi-participant testing
3. Check logs regularly: `docker-compose logs -f`
4. Clean up test recordings: `rm -rf recordings/*.mka`

### For Production

1. Use strong passwords (generated by the script)
2. Enable authentication for sensitive meetings
3. Set up monitoring and log rotation
4. Regular backups of recordings
5. Keep Docker images updated
6. Configure firewall properly
7. Test from external network before going live

## Additional Resources

- [Main README](../README.md) - Setup and general usage
- [Localhost Testing Guide](LOCALHOST_TESTING.md) - Detailed testing instructions
- [Architecture](ARCHITECTURE.md) - System architecture overview
- [Jitsi Handbook](https://jitsi.github.io/handbook/) - Official Jitsi documentation

---

**Last Updated**: 2025-11-14
**Version**: 1.0
