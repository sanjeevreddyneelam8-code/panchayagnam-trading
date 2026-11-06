# Panchayagnam · 1-Click Cloud Deployment Guide

This guide explains how to deploy the Panchayagnam backend to the cloud for free or low cost, enabling 24/7 background trade execution.

---

## Option 1: 1-Click Render.com Deployment (Recommended)

1. Create a free account on [Render.com](https://render.com/).
2. Click **New +** $\rightarrow$ **Blueprint**.
3. Connect your GitHub repository: `https://github.com/sanjeevreddyneelam8-code/panchayagnam-trading`.
4. Render will automatically detect `render.yaml` and configure:
   - **`panchayagnam-api`**: Spring Boot Web Service
   - **`panchayagnam-db`**: PostgreSQL Database
5. Click **Apply**.
6. Once deployed, copy your API URL: `https://panchayagnam-api.onrender.com`.

---

## Option 2: Docker Compose (For VPS / AWS EC2 / DigitalOcean)

If you have a Linux VPS (Ubuntu 22.04 / 24.04):

```bash
# Clone the repository
git clone https://github.com/sanjeevreddyneelam8-code/panchayagnam-trading.git
cd panchayagnam-trading

# Start all services with Docker Compose
docker compose up -d --build

# Check status
docker compose ps
```

All microservices (Core Backend, Broker Gateway, MySQL, and Nginx UI) will start automatically with health checks.
