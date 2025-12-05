# DevOps и CI/CD VibeMon

## 1. Docker Compose (Development)

```yaml
# docker-compose.yml
version: '3.9'

services:
  # ===========================================
  # DATABASE
  # ===========================================
  timescaledb:
    image: timescale/timescaledb:latest-pg15
    container_name: vibemon-db
    environment:
      POSTGRES_USER: vibemon
      POSTGRES_PASSWORD: ${DB_PASSWORD:-vibemon_dev}
      POSTGRES_DB: vibemon
    ports:
      - "5432:5432"
    volumes:
      - timescale_data:/var/lib/postgresql/data
      - ./infrastructure/db/init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vibemon"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - vibemon-network

  redis:
    image: redis:7-alpine
    container_name: vibemon-redis
    command: redis-server --appendonly yes
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - vibemon-network

  # ===========================================
  # OBJECT STORAGE
  # ===========================================
  minio:
    image: minio/minio:latest
    container_name: vibemon-minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_USER:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_PASSWORD:-minioadmin}
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio_data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3
    networks:
      - vibemon-network

  # ===========================================
  # API SERVICE (FastAPI)
  # ===========================================
  api:
    build:
      context: ./backend/api
      dockerfile: Dockerfile
    container_name: vibemon-api
    environment:
      DATABASE_URL: postgresql://vibemon:${DB_PASSWORD:-vibemon_dev}@timescaledb:5432/vibemon
      REDIS_URL: redis://redis:6379/0
      JWT_SECRET: ${JWT_SECRET:-dev_secret_key_change_in_production}
      MINIO_ENDPOINT: minio:9000
      MINIO_ACCESS_KEY: ${MINIO_USER:-minioadmin}
      MINIO_SECRET_KEY: ${MINIO_PASSWORD:-minioadmin}
      ENVIRONMENT: development
    ports:
      - "8000:8000"
    volumes:
      - ./backend/api:/app
    depends_on:
      timescaledb:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - vibemon-network

  # ===========================================
  # WEBSOCKET SERVICE (Go)
  # ===========================================
  websocket:
    build:
      context: ./backend/websocket
      dockerfile: Dockerfile
    container_name: vibemon-websocket
    environment:
      REDIS_URL: redis://redis:6379/0
      JWT_SECRET: ${JWT_SECRET:-dev_secret_key_change_in_production}
      PORT: 8080
    ports:
      - "8080:8080"
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - vibemon-network

  # ===========================================
  # ML SERVICE
  # ===========================================
  ml:
    build:
      context: ./backend/ml
      dockerfile: Dockerfile
    container_name: vibemon-ml
    environment:
      DATABASE_URL: postgresql://vibemon:${DB_PASSWORD:-vibemon_dev}@timescaledb:5432/vibemon
      REDIS_URL: redis://redis:6379/0
      MODEL_PATH: /app/models
    ports:
      - "8001:8001"
    volumes:
      - ./backend/ml:/app
      - ml_models:/app/models
    depends_on:
      timescaledb:
        condition: service_healthy
    networks:
      - vibemon-network

  # ===========================================
  # CELERY WORKER
  # ===========================================
  worker:
    build:
      context: ./backend/worker
      dockerfile: Dockerfile
    container_name: vibemon-worker
    command: celery -A app.celery_app worker --loglevel=info
    environment:
      DATABASE_URL: postgresql://vibemon:${DB_PASSWORD:-vibemon_dev}@timescaledb:5432/vibemon
      REDIS_URL: redis://redis:6379/0
      SMTP_HOST: ${SMTP_HOST:-mailhog}
      SMTP_PORT: ${SMTP_PORT:-1025}
      TELEGRAM_BOT_TOKEN: ${TELEGRAM_BOT_TOKEN:-}
    volumes:
      - ./backend/worker:/app
    depends_on:
      timescaledb:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - vibemon-network

  # ===========================================
  # CELERY BEAT (Scheduler)
  # ===========================================
  beat:
    build:
      context: ./backend/worker
      dockerfile: Dockerfile
    container_name: vibemon-beat
    command: celery -A app.celery_app beat --loglevel=info
    environment:
      DATABASE_URL: postgresql://vibemon:${DB_PASSWORD:-vibemon_dev}@timescaledb:5432/vibemon
      REDIS_URL: redis://redis:6379/0
    depends_on:
      - worker
    networks:
      - vibemon-network

  # ===========================================
  # ADMIN PANEL (Next.js)
  # ===========================================
  admin:
    build:
      context: ./admin
      dockerfile: Dockerfile
      target: development
    container_name: vibemon-admin
    environment:
      NEXT_PUBLIC_API_URL: http://localhost:8000/v1
      NEXT_PUBLIC_WS_URL: ws://localhost:8080/ws
    ports:
      - "3000:3000"
    volumes:
      - ./admin:/app
      - /app/node_modules
      - /app/.next
    networks:
      - vibemon-network

  # ===========================================
  # REVERSE PROXY
  # ===========================================
  traefik:
    image: traefik:v2.10
    container_name: vibemon-traefik
    command:
      - "--api.dashboard=true"
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
    ports:
      - "80:80"
      - "8090:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - vibemon-network

  # ===========================================
  # DEV TOOLS
  # ===========================================
  mailhog:
    image: mailhog/mailhog
    container_name: vibemon-mailhog
    ports:
      - "1025:1025"
      - "8025:8025"
    networks:
      - vibemon-network

  adminer:
    image: adminer
    container_name: vibemon-adminer
    ports:
      - "8081:8080"
    networks:
      - vibemon-network

volumes:
  timescale_data:
  redis_data:
  minio_data:
  ml_models:

networks:
  vibemon-network:
    driver: bridge
```

---

## 2. Docker Compose (Production)

```yaml
# docker-compose.prod.yml
version: '3.9'

services:
  timescaledb:
    image: timescale/timescaledb:latest-pg15
    container_name: vibemon-db
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - timescale_data:/var/lib/postgresql/data
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
    restart: unless-stopped
    networks:
      - vibemon-internal

  redis:
    image: redis:7-alpine
    container_name: vibemon-redis
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
    restart: unless-stopped
    networks:
      - vibemon-internal

  api:
    image: ${REGISTRY}/vibemon-api:${VERSION}
    container_name: vibemon-api
    environment:
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL}
      JWT_SECRET: ${JWT_SECRET}
      ENVIRONMENT: production
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '1'
          memory: 1G
      update_config:
        parallelism: 1
        delay: 10s
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`api.vibemon.io`)"
      - "traefik.http.routers.api.tls=true"
      - "traefik.http.routers.api.tls.certresolver=letsencrypt"
    networks:
      - vibemon-internal
      - vibemon-public

  websocket:
    image: ${REGISTRY}/vibemon-websocket:${VERSION}
    container_name: vibemon-websocket
    environment:
      REDIS_URL: ${REDIS_URL}
      JWT_SECRET: ${JWT_SECRET}
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.ws.rule=Host(`ws.vibemon.io`)"
      - "traefik.http.routers.ws.tls=true"
    networks:
      - vibemon-internal
      - vibemon-public

  ml:
    image: ${REGISTRY}/vibemon-ml:${VERSION}
    container_name: vibemon-ml
    environment:
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL}
    volumes:
      - ml_models:/app/models
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
    restart: unless-stopped
    networks:
      - vibemon-internal

  worker:
    image: ${REGISTRY}/vibemon-worker:${VERSION}
    container_name: vibemon-worker
    command: celery -A app.celery_app worker --loglevel=warning --concurrency=4
    environment:
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL}
      SMTP_HOST: ${SMTP_HOST}
      SMTP_USER: ${SMTP_USER}
      SMTP_PASSWORD: ${SMTP_PASSWORD}
      TELEGRAM_BOT_TOKEN: ${TELEGRAM_BOT_TOKEN}
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1'
          memory: 1G
    restart: unless-stopped
    networks:
      - vibemon-internal

  admin:
    image: ${REGISTRY}/vibemon-admin:${VERSION}
    container_name: vibemon-admin
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.admin.rule=Host(`app.vibemon.io`)"
      - "traefik.http.routers.admin.tls=true"
    restart: unless-stopped
    networks:
      - vibemon-public

  traefik:
    image: traefik:v2.10
    container_name: vibemon-traefik
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.email=${ACME_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - letsencrypt:/letsencrypt
    restart: unless-stopped
    networks:
      - vibemon-public

volumes:
  timescale_data:
  redis_data:
  ml_models:
  letsencrypt:

networks:
  vibemon-internal:
    driver: bridge
    internal: true
  vibemon-public:
    driver: bridge
```

---

## 3. GitHub Actions CI/CD

### 3.1 CI Pipeline

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

env:
  PYTHON_VERSION: '3.11'
  NODE_VERSION: '20'
  GO_VERSION: '1.21'
  FLUTTER_VERSION: '3.16.0'

jobs:
  # ===========================================
  # BACKEND API TESTS
  # ===========================================
  api-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: timescale/timescaledb:latest-pg15
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}

      - name: Cache pip
        uses: actions/cache@v3
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-pip-${{ hashFiles('backend/api/requirements.txt') }}

      - name: Install dependencies
        working-directory: backend/api
        run: |
          pip install -r requirements.txt
          pip install pytest pytest-cov pytest-asyncio

      - name: Run tests
        working-directory: backend/api
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/test
          REDIS_URL: redis://localhost:6379/0
          JWT_SECRET: test_secret
        run: |
          pytest tests/ -v --cov=app --cov-report=xml

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: backend/api/coverage.xml
          flags: api

  # ===========================================
  # WEBSOCKET SERVICE TESTS
  # ===========================================
  websocket-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}

      - name: Cache Go modules
        uses: actions/cache@v3
        with:
          path: ~/go/pkg/mod
          key: ${{ runner.os }}-go-${{ hashFiles('backend/websocket/go.sum') }}

      - name: Run tests
        working-directory: backend/websocket
        run: |
          go test -v -race -coverprofile=coverage.out ./...

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: backend/websocket/coverage.out
          flags: websocket

  # ===========================================
  # ML SERVICE TESTS
  # ===========================================
  ml-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}

      - name: Install dependencies
        working-directory: backend/ml
        run: |
          pip install -r requirements.txt
          pip install pytest

      - name: Run tests
        working-directory: backend/ml
        run: pytest tests/ -v

  # ===========================================
  # ADMIN PANEL TESTS
  # ===========================================
  admin-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: admin/package-lock.json

      - name: Install dependencies
        working-directory: admin
        run: npm ci

      - name: Lint
        working-directory: admin
        run: npm run lint

      - name: Type check
        working-directory: admin
        run: npm run type-check

      - name: Run tests
        working-directory: admin
        run: npm test -- --coverage

      - name: Build
        working-directory: admin
        run: npm run build

  # ===========================================
  # MOBILE APP TESTS
  # ===========================================
  mobile-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Get dependencies
        working-directory: mobile
        run: flutter pub get

      - name: Analyze
        working-directory: mobile
        run: flutter analyze

      - name: Run tests
        working-directory: mobile
        run: flutter test --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: mobile/coverage/lcov.info
          flags: mobile

  # ===========================================
  # FIRMWARE BUILD
  # ===========================================
  firmware-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Cache PlatformIO
        uses: actions/cache@v3
        with:
          path: |
            ~/.platformio
            ~/.cache/pip
          key: ${{ runner.os }}-pio-${{ hashFiles('firmware/platformio.ini') }}

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}

      - name: Install PlatformIO
        run: pip install platformio

      - name: Build firmware
        working-directory: firmware
        run: pio run

      - name: Run tests
        working-directory: firmware
        run: pio test

  # ===========================================
  # DOCKER BUILD
  # ===========================================
  docker-build:
    runs-on: ubuntu-latest
    needs: [api-tests, websocket-tests, admin-tests]
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build API image
        uses: docker/build-push-action@v5
        with:
          context: ./backend/api
          push: false
          tags: vibemon-api:test
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Build WebSocket image
        uses: docker/build-push-action@v5
        with:
          context: ./backend/websocket
          push: false
          tags: vibemon-websocket:test

      - name: Build Admin image
        uses: docker/build-push-action@v5
        with:
          context: ./admin
          push: false
          tags: vibemon-admin:test
```

### 3.2 CD Staging Pipeline

```yaml
# .github/workflows/cd-staging.yml
name: CD Staging

on:
  push:
    branches: [develop]

env:
  REGISTRY: ghcr.io
  IMAGE_PREFIX: ${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Extract version
        id: version
        run: echo "VERSION=staging-$(git rev-parse --short HEAD)" >> $GITHUB_OUTPUT

      - name: Build and push API
        uses: docker/build-push-action@v5
        with:
          context: ./backend/api
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/api:${{ steps.version.outputs.VERSION }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/api:staging

      - name: Build and push WebSocket
        uses: docker/build-push-action@v5
        with:
          context: ./backend/websocket
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/websocket:${{ steps.version.outputs.VERSION }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/websocket:staging

      - name: Build and push ML
        uses: docker/build-push-action@v5
        with:
          context: ./backend/ml
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/ml:${{ steps.version.outputs.VERSION }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/ml:staging

      - name: Build and push Worker
        uses: docker/build-push-action@v5
        with:
          context: ./backend/worker
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/worker:${{ steps.version.outputs.VERSION }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/worker:staging

      - name: Build and push Admin
        uses: docker/build-push-action@v5
        with:
          context: ./admin
          push: true
          build-args: |
            NEXT_PUBLIC_API_URL=https://api-staging.vibemon.io/v1
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/admin:${{ steps.version.outputs.VERSION }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/admin:staging

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    environment: staging

    steps:
      - uses: actions/checkout@v4

      - name: Deploy to staging
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.STAGING_HOST }}
          username: ${{ secrets.STAGING_USER }}
          key: ${{ secrets.STAGING_SSH_KEY }}
          script: |
            cd /opt/vibemon
            docker compose -f docker-compose.staging.yml pull
            docker compose -f docker-compose.staging.yml up -d
            docker system prune -f

      - name: Health check
        run: |
          sleep 30
          curl -f https://api-staging.vibemon.io/health || exit 1

      - name: Notify Slack
        uses: slackapi/slack-github-action@v1.24.0
        with:
          payload: |
            {
              "text": "✅ Staging deployment successful",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Staging deployment successful*\nCommit: ${{ github.sha }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

### 3.3 CD Production Pipeline

```yaml
# .github/workflows/cd-production.yml
name: CD Production

on:
  release:
    types: [published]

env:
  REGISTRY: ghcr.io
  IMAGE_PREFIX: ${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Get version
        id: version
        run: echo "VERSION=${{ github.event.release.tag_name }}" >> $GITHUB_OUTPUT

      - name: Build and push all images
        run: |
          VERSION=${{ steps.version.outputs.VERSION }}
          
          # API
          docker buildx build --push \
            -t ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/api:${VERSION} \
            -t ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/api:latest \
            ./backend/api
          
          # WebSocket
          docker buildx build --push \
            -t ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/websocket:${VERSION} \
            -t ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/websocket:latest \
            ./backend/websocket
          
          # ML
          docker buildx build --push \
            -t ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/ml:${VERSION} \
            -t ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/ml:latest \
            ./backend/ml
          
          # Worker
          docker buildx build --push \
            -t ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/worker:${VERSION} \
            -t ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/worker:latest \
            ./backend/worker
          
          # Admin
          docker buildx build --push \
            --build-arg NEXT_PUBLIC_API_URL=https://api.vibemon.io/v1 \
            -t ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/admin:${VERSION} \
            -t ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/admin:latest \
            ./admin

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    environment: production

    steps:
      - uses: actions/checkout@v4

      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          kubeconfig: ${{ secrets.KUBE_CONFIG }}

      - name: Deploy to Kubernetes
        run: |
          VERSION=${{ github.event.release.tag_name }}
          
          # Update image versions
          kubectl set image deployment/api api=${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/api:${VERSION} -n vibemon
          kubectl set image deployment/websocket websocket=${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/websocket:${VERSION} -n vibemon
          kubectl set image deployment/ml ml=${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/ml:${VERSION} -n vibemon
          kubectl set image deployment/worker worker=${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/worker:${VERSION} -n vibemon
          kubectl set image deployment/admin admin=${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/admin:${VERSION} -n vibemon
          
          # Wait for rollout
          kubectl rollout status deployment/api -n vibemon --timeout=300s
          kubectl rollout status deployment/websocket -n vibemon --timeout=300s
          kubectl rollout status deployment/admin -n vibemon --timeout=300s

      - name: Run database migrations
        run: |
          kubectl exec -n vibemon deployment/api -- alembic upgrade head

      - name: Notify success
        uses: slackapi/slack-github-action@v1.24.0
        with:
          payload: |
            {
              "text": "🚀 Production deployment successful",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Production deployment successful*\nVersion: ${{ github.event.release.tag_name }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

### 3.4 Mobile Build Pipeline

```yaml
# .github/workflows/mobile-build.yml
name: Mobile Build

on:
  push:
    tags:
      - 'mobile-v*'

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          cache: true

      - name: Get dependencies
        working-directory: mobile
        run: flutter pub get

      - name: Decode keystore
        env:
          KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
        run: |
          echo $KEYSTORE_BASE64 | base64 -d > mobile/android/app/release.keystore

      - name: Build APK
        working-directory: mobile
        env:
          KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
          STORE_PASSWORD: ${{ secrets.ANDROID_STORE_PASSWORD }}
        run: |
          flutter build apk --release
          flutter build appbundle --release

      - name: Upload APK
        uses: actions/upload-artifact@v3
        with:
          name: android-release
          path: |
            mobile/build/app/outputs/flutter-apk/app-release.apk
            mobile/build/app/outputs/bundle/release/app-release.aab

      - name: Upload to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: io.vibemon.app
          releaseFiles: mobile/build/app/outputs/bundle/release/app-release.aab
          track: internal

  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          cache: true

      - name: Get dependencies
        working-directory: mobile
        run: flutter pub get

      - name: Install CocoaPods
        working-directory: mobile/ios
        run: pod install

      - name: Build iOS
        working-directory: mobile
        run: |
          flutter build ios --release --no-codesign

      - name: Build IPA
        working-directory: mobile/ios
        env:
          APPLE_CERTIFICATE: ${{ secrets.APPLE_CERTIFICATE }}
          APPLE_CERTIFICATE_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
          APPLE_PROVISIONING_PROFILE: ${{ secrets.APPLE_PROVISIONING_PROFILE }}
        run: |
          # Setup signing
          # Build IPA
          xcodebuild -workspace Runner.xcworkspace \
            -scheme Runner \
            -configuration Release \
            -archivePath build/Runner.xcarchive \
            archive
          
          xcodebuild -exportArchive \
            -archivePath build/Runner.xcarchive \
            -exportOptionsPlist ExportOptions.plist \
            -exportPath build/ipa

      - name: Upload to TestFlight
        uses: apple-actions/upload-testflight-build@v1
        with:
          app-path: mobile/ios/build/ipa/Runner.ipa
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_API_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_API_PRIVATE_KEY }}
```

---

## 4. Makefile

```makefile
# Makefile

.PHONY: help dev prod test clean build deploy

# Default target
help:
	@echo "VibeMon Development Commands"
	@echo ""
	@echo "  make dev          - Start development environment"
	@echo "  make prod         - Start production environment"
	@echo "  make test         - Run all tests"
	@echo "  make build        - Build all Docker images"
	@echo "  make clean        - Clean up containers and volumes"
	@echo "  make migrate      - Run database migrations"
	@echo "  make logs         - Show logs"
	@echo "  make shell-api    - Open shell in API container"
	@echo ""

# Development
dev:
	docker compose up -d
	@echo "Development environment started"
	@echo "API: http://localhost:8000"
	@echo "Admin: http://localhost:3000"
	@echo "Adminer: http://localhost:8081"
	@echo "MailHog: http://localhost:8025"

dev-build:
	docker compose up -d --build

dev-down:
	docker compose down

# Production
prod:
	docker compose -f docker-compose.prod.yml up -d

prod-down:
	docker compose -f docker-compose.prod.yml down

# Testing
test:
	@echo "Running API tests..."
	cd backend/api && pytest tests/ -v
	@echo "Running WebSocket tests..."
	cd backend/websocket && go test ./...
	@echo "Running Admin tests..."
	cd admin && npm test
	@echo "Running Mobile tests..."
	cd mobile && flutter test

test-api:
	cd backend/api && pytest tests/ -v --cov=app

test-mobile:
	cd mobile && flutter test --coverage

# Build
build:
	docker compose build

build-api:
	docker build -t vibemon-api:latest ./backend/api

build-admin:
	docker build -t vibemon-admin:latest ./admin

build-firmware:
	cd firmware && pio run

# Database
migrate:
	docker compose exec api alembic upgrade head

migrate-create:
	docker compose exec api alembic revision --autogenerate -m "$(name)"

# Logs
logs:
	docker compose logs -f

logs-api:
	docker compose logs -f api

logs-worker:
	docker compose logs -f worker

# Shell access
shell-api:
	docker compose exec api bash

shell-db:
	docker compose exec timescaledb psql -U vibemon

# Cleanup
clean:
	docker compose down -v
	docker system prune -f

clean-all:
	docker compose down -v --rmi all
	docker system prune -af

# Utilities
format:
	cd backend/api && black app/ tests/
	cd admin && npm run format
	cd mobile && flutter format lib/

lint:
	cd backend/api && flake8 app/ tests/
	cd admin && npm run lint
	cd mobile && flutter analyze
```

---

## 5. Инструкции по сборке

### 5.1 Локальная разработка

```bash
# 1. Клонирование репозитория
git clone https://github.com/vibemon/vibemon.git
cd vibemon

# 2. Копирование переменных окружения
cp .env.example .env

# 3. Запуск инфраструктуры
make dev

# 4. Применение миграций
make migrate

# 5. Проверка работоспособности
curl http://localhost:8000/health
```

### 5.2 Сборка прошивки ESP32

```bash
# 1. Установка PlatformIO
pip install platformio

# 2. Сборка
cd firmware
pio run

# 3. Загрузка в устройство
pio run -t upload

# 4. Мониторинг
pio device monitor
```

### 5.3 Сборка мобильного приложения

```bash
# 1. Установка Flutter
# https://flutter.dev/docs/get-started/install

# 2. Проверка
flutter doctor

# 3. Установка зависимостей
cd mobile
flutter pub get

# 4. Сборка Android
flutter build apk --release

# 5. Сборка iOS (только на macOS)
flutter build ios --release
```

---

*Документ: DevOps и CI/CD VibeMon v1.0*
