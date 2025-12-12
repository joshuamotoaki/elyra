# Elyra Deployment Guide

This guide covers deploying Elyra to an AWS EC2 instance with Docker containers.

**Domain**: `elyra.tigerapps.org`

## Architecture

```
Internet → Nginx (SSL) → Frontend (:3000) / Backend (:4000) → PostgreSQL (:5432)
```

- **Nginx**: Reverse proxy with SSL termination
- **Frontend**: SvelteKit application
- **Backend**: Phoenix/Elixir API + WebSocket server
- **PostgreSQL**: Database

---

## 1. EC2 Instance Setup

### Requirements
- **Instance type**: t3.small or larger (2GB+ RAM recommended)
- **OS**: Ubuntu 24.04 LTS
- **Storage**: 20GB+ EBS

### Security Groups
Configure inbound rules:

| Type  | Port | Source    |
|-------|------|-----------|
| SSH   | 22   | Your IP   |
| HTTP  | 80   | 0.0.0.0/0 |
| HTTPS | 443  | 0.0.0.0/0 |

---

## 2. Server Initial Setup

SSH into your EC2 instance:

```bash
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>
```

### Install Docker

```bash
# Update packages
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

# Log out and back in for group changes to take effect
exit
```

SSH back in and verify:

```bash
docker --version
docker compose version
```

### Install Git

```bash
sudo apt install -y git
```

---

## 3. Clone Repository

```bash
cd /home/ubuntu
git clone https://github.com/joshuamotoaki/elyra.git
cd elyra
```

---

## 4. Environment Variables

Create the production environment file:

```bash
nano .env.prod
```

Add the following (replace placeholder values):

```bash
# Database
DATABASE_URL=ecto://postgres:YOUR_SECURE_PASSWORD@postgres:5432/elyra
POSTGRES_PASSWORD=YOUR_SECURE_PASSWORD

# Phoenix
SECRET_KEY_BASE=<generate-with-mix-phx.gen.secret>
PHX_HOST=elyra.tigerapps.org
PORT=4000

# Google OAuth
GOOGLE_CLIENT_ID=<your-google-client-id>
GOOGLE_CLIENT_SECRET=<your-google-client-secret>

# Guardian JWT
GUARDIAN_SECRET_KEY=<generate-with-mix-phx.gen.secret>
```

### Generate Secrets

On your local machine (with Elixir installed):

```bash
cd backend
mix phx.gen.secret  # Use for SECRET_KEY_BASE
mix phx.gen.secret  # Use for GUARDIAN_SECRET_KEY
```

Or generate a random string:

```bash
openssl rand -base64 64 | tr -d '\n'
```

---

## 5. DNS Configuration

Add an A record in your DNS provider:

| Type | Name  | Value           |
|------|-------|-----------------|
| A    | elyra | <EC2_PUBLIC_IP> |

This points `elyra.tigerapps.org` to your EC2 instance.

**Note**: DNS propagation may take a few minutes to hours.

---

## 6. SSL Certificate Setup (Let's Encrypt)

### Initial Certificate

Before starting the full stack, get SSL certificates:

```bash
# Create certbot directories
mkdir -p certbot/conf certbot/www

# Get initial certificate (nginx must be stopped)
docker run -it --rm \
  -v $(pwd)/certbot/conf:/etc/letsencrypt \
  -v $(pwd)/certbot/www:/var/www/certbot \
  -p 80:80 \
  certbot/certbot certonly \
  --standalone \
  --email your-email@example.com \
  --agree-tos \
  --no-eff-email \
  -d elyra.tigerapps.org
```

Certificates will be stored in `certbot/conf/live/elyra.tigerapps.org/`.

---

## 7. Google OAuth Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Navigate to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth client ID**
5. Configure the OAuth consent screen:
   - User Type: External
   - App name: Elyra
   - Support email: your email
   - Authorized domains: `tigerapps.org`
6. Create OAuth 2.0 Client ID:
   - Application type: Web application
   - Name: Elyra Production
   - Authorized redirect URIs:
     ```
     https://elyra.tigerapps.org/api/auth/google/callback
     ```
7. Copy the **Client ID** and **Client Secret** to `.env.prod`

---

## 8. Initial Deployment

### First-Time Setup (Before CI/CD is configured)

For the initial deployment, you need to trigger the GitHub Actions workflow first to build and push the images. Either:
1. Push a commit to `main` branch, OR
2. Manually trigger the workflow from GitHub Actions tab

### Start Services

```bash
cd /home/ubuntu/elyra

# Create .env file for POSTGRES_PASSWORD
echo "POSTGRES_PASSWORD=YOUR_SECURE_PASSWORD" > .env

# Log in to GitHub Container Registry (if packages are private)
echo "YOUR_GHCR_TOKEN" | docker login ghcr.io -u joshuamotoaki --password-stdin

# Pull and start all containers
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d

# Check status
docker compose -f docker-compose.prod.yml ps

# View logs
docker compose -f docker-compose.prod.yml logs -f
```

### Run Database Migrations

```bash
docker compose -f docker-compose.prod.yml exec backend bin/backend eval "Backend.Release.migrate"
```

**Note**: If the above doesn't work, you may need to create a Release module. Alternatively, run migrations manually:

```bash
docker compose -f docker-compose.prod.yml exec backend bin/backend remote

# In the Elixir shell:
Ecto.Migrator.run(Backend.Repo, :up, all: true)
```

---

## 9. GitHub Actions CD Setup

The CI/CD pipeline builds Docker images in GitHub Actions (which has more memory) and pushes them to GitHub Container Registry (GHCR). The EC2 instance only pulls and runs the pre-built images.

### Create a Personal Access Token (PAT) for GHCR

1. Go to GitHub → **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Click **Generate new token (classic)**
3. Set:
   - Note: `elyra-ghcr`
   - Expiration: 90 days (or longer)
   - Scopes: `read:packages`, `write:packages`
4. Copy the token

### Configure Repository Secrets

**Settings** → **Secrets and variables** → **Actions** → **New repository secret**

| Secret Name   | Value                                      |
|---------------|-------------------------------------------|
| EC2_HOST      | Your EC2 public IP or hostname            |
| EC2_USER      | `ubuntu`                                  |
| EC2_SSH_KEY   | Contents of your EC2 private key (.pem)   |
| GHCR_TOKEN    | Your GitHub PAT with `read:packages`      |

### Generate SSH Key (if needed)

```bash
# On your local machine
ssh-keygen -t ed25519 -C "github-actions"

# Copy public key to EC2
ssh-copy-id -i ~/.ssh/id_ed25519.pub ubuntu@<EC2_PUBLIC_IP>

# Copy private key content for GitHub secret
cat ~/.ssh/id_ed25519
```

**Important**: Ensure the private key includes `-----BEGIN` and `-----END` lines.

### Make Package Public (Optional)

After the first successful build, go to your GitHub profile → **Packages** → select the package → **Package settings** → **Change visibility** → **Public**. This removes the need for authentication when pulling.

---

## 10. Useful Commands

### View Logs

```bash
# All services
docker compose -f docker-compose.prod.yml logs -f

# Specific service
docker compose -f docker-compose.prod.yml logs -f backend
docker compose -f docker-compose.prod.yml logs -f frontend
docker compose -f docker-compose.prod.yml logs -f nginx
```

### Restart Services

```bash
# Restart all
docker compose -f docker-compose.prod.yml restart

# Restart specific service
docker compose -f docker-compose.prod.yml restart backend
```

### Pull Latest and Deploy

```bash
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

### Database Access

```bash
docker compose -f docker-compose.prod.yml exec postgres psql -U postgres -d elyra
```

### Clean Up

```bash
# Remove unused images and containers
docker system prune -f

# Remove all (including volumes - CAREFUL!)
docker system prune -a --volumes
```

### SSL Certificate Renewal

Certificates auto-renew via the certbot container. To manually renew:

```bash
docker compose -f docker-compose.prod.yml run --rm certbot renew
docker compose -f docker-compose.prod.yml restart nginx
```

---

## Troubleshooting

### Container won't start

Check logs:
```bash
docker compose -f docker-compose.prod.yml logs <service-name>
```

### Database connection issues

Ensure postgres is healthy:
```bash
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml exec postgres pg_isready -U postgres
```

### SSL certificate issues

Verify certificate exists:
```bash
ls -la certbot/conf/live/elyra.tigerapps.org/
```

### WebSocket connection issues

Check nginx logs and ensure `/socket` route is properly proxying:
```bash
docker compose -f docker-compose.prod.yml logs nginx
```

---

## File Structure

```
elyra/
├── .env.prod                    # Production environment variables
├── docker-compose.prod.yml      # Production Docker Compose
├── nginx/
│   └── nginx.conf               # Nginx configuration
├── certbot/
│   ├── conf/                    # SSL certificates
│   └── www/                     # ACME challenge files
├── backend/
│   └── Dockerfile.prod          # Backend production image
└── frontend/
    └── Dockerfile.prod          # Frontend production image
```
