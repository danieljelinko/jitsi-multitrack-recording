# Deployment Checklist for Admins & Agents

Use this document whenever you clone **jitsi-multitrack-recording** onto a fresh
host. It clearly separates the steps that **must** be run manually by a system
administrator (sudo, package installs, Maven downloads) from the tasks an
automation agent can take over once the prerequisites are satisfied.

---

## 1. System Administrator TODOs (manual commands)

Run all commands from the host shell **before** giving an agent access.

1. **Install base packages**
   ```bash
   sudo apt-get update
   sudo apt-get install -y \
     docker.io docker-compose git openssl ffmpeg \
     openjdk-17-jdk maven
   sudo systemctl enable --now docker
   sudo usermod -aG docker "$USER"
   ```
   *Log out/in if needed so your shell can run `docker` without sudo.*

2. **Clone repositories**
   ```bash
   cd ~/Work/guess-class
   git clone https://github.com/your-org/jitsi-multitrack-recording.git
   git clone https://github.com/jitsi/jitsi-videobridge.git
   git clone https://github.com/jitsi/jicofo.git
   ```

3. **Build multitrack-enabled jars**
   ```bash
   cd ~/Work/guess-class/jitsi-videobridge
   mvn clean package -DskipTests

   cd ~/Work/guess-class/jicofo
   mvn clean package -DskipTests
   ```

4. **Stage jars for Docker builds**
   ```bash
   cd ~/Work/guess-class/jitsi-multitrack-recording
   mkdir -p docker/jvb docker/jicofo
   cp ~/Work/guess-class/jitsi-videobridge/jvb/target/jitsi-videobridge-2.3-SNAPSHOT.jar docker/jvb/jitsi-videobridge.jar
   cp ~/Work/guess-class/jicofo/jicofo/target/jicofo-1.1-SNAPSHOT-jar-with-dependencies.jar docker/jicofo/jicofo.jar
   ```

5. **Build the custom Docker images**
   ```bash
   docker-compose build jvb
   docker-compose build jicofo
   ```

6. **(Optional) push images to a registry** if you don’t want to rebuild on
   other hosts:
   ```bash
   docker tag jvb-multitrack:latest ghcr.io/<org>/jvb-multitrack:<tag>
   docker push ghcr.io/<org>/jvb-multitrack:<tag>
   # same for jicofo-multitrack
   ```

7. **Hand the machine off to the automation agent** (no sudo required once the
   steps above are complete).

---

## 2. Agent TODOs (no sudo required)

Agents should follow these steps, all from the `jitsi-multitrack-recording`
directory:

1. **Generate configuration**
   ```bash
   ./scripts/generate-passwords.sh
   ```
   Respond to prompts (PUBLIC_URL, auto-recording). For production hosts copy
   `.env.production` first if needed.

2. **Start or restart the stack**
   ```bash
   docker-compose up -d
   ```
   (If the admin already had containers running, use
   `docker-compose rm -fs jvb jicofo && docker-compose up -d jvb jicofo` to pick
   up new images.)

3. **Verify services**
   ```bash
   docker-compose ps
   curl -k -s -o /dev/null -w "%{http_code}" https://localhost:8443
   ```

4. **Validate recording path**
   - Join a room with multiple participants.
   - Tail logs:
     ```bash
     docker-compose logs -f jvb recorder
     ```
     Expect exporter WebSocket connection lines and recorder “Recording session
     started” messages.

5. **Confirm output files**
   ```bash
   ./scripts/list-recordings.sh
   ./scripts/extract-tracks.sh recordings/<room>.mka wav
   ```

6. **Document jar/image versions** (record git commits or registry tags).

---

## 3. Troubleshooting Notes

- If Maven fails with “permission denied” in `~/.m2`, the admin must clean up
  the offending directories (only they have sudo).
- `docker-compose up` errors like `ContainerConfig` usually mean an old
  container needs to be removed (`docker-compose rm -fs <service>`).
- The exporter logs won’t appear unless both custom jars are in use **and**
  the client is sending Colibri2 `connects` (handled by the patched Jicofo).

---

**Reference:** For a deeper walkthrough of the custom container pipeline, see
`SETUP_CUSTOM_CONTAINERS_HOWTO.md`.
