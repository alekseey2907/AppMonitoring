# VibeMon 🔧📊

**Система предиктивного мониторинга вибрации и температуры для сельскохозяйственной и промышленной техники**

[![CI](https://github.com/vibemon/vibemon/actions/workflows/ci.yml/badge.svg)](https://github.com/vibemon/vibemon/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

---

## 🎯 О проекте

VibeMon — комплексная система для мониторинга состояния механизмов в реальном времени. Позволяет предотвращать поломки, снижать время простоя и оптимизировать затраты на техническое обслуживание.

### Ключевые возможности

- 📡 **Real-time мониторинг** — отслеживание вибрации и температуры в реальном времени через BLE
- 🤖 **ИИ-аналитика** — автоматическое обнаружение аномалий и предиктивная диагностика
- 📱 **Мобильное приложение** — кроссплатформенное приложение для Android и iOS
- 🌐 **Веб-панель** — административная панель для управления парком устройств
- 🔔 **Уведомления** — мгновенные алерты через Telegram, Email и Push
- 📈 **Отчёты** — детальная аналитика и отчёты в PDF/CSV

---

## 📚 Документация

| Документ | Описание |
|----------|----------|
| [Техническое задание](docs/01-TECHNICAL_SPECIFICATION.md) | Полное ТЗ с требованиями |
| [Архитектура](docs/02-ARCHITECTURE.md) | Диаграммы и описание архитектуры |
| [BLE Протокол](docs/03-BLE_PROTOCOL.md) | Спецификация BLE протокола |
| [База данных](docs/04-DATABASE_SCHEMA.md) | ER-диаграмма и схема БД |
| [API Specification](docs/05-API_SPECIFICATION.md) | REST API документация |
| [Структура проекта](docs/06-PROJECT_STRUCTURE.md) | Описание структуры каталогов |
| [Бизнес-план](docs/07-BUSINESS_PLAN.md) | Монетизация и use cases |
| [DevOps](docs/08-DEVOPS_CICD.md) | CI/CD и инфраструктура |

---

## 🏗️ Архитектура

```
┌─────────────┐      BLE       ┌─────────────┐     HTTPS      ┌─────────────┐
│   ESP32     │◄──────────────►│   Mobile    │───────────────►│   Backend   │
│   Device    │                │   App       │                │   (Cloud)   │
│             │                │  (Flutter)  │                │             │
│ • MPU6050   │                │ • BLE       │                │ • FastAPI   │
│ • DS18B20   │                │ • Offline   │                │ • Go WS     │
│ • BLE 5.0   │                │ • Charts    │                │ • ML        │
└─────────────┘                └─────────────┘                └─────────────┘
                                                                     │
                                                              ┌──────┴──────┐
                                                              │             │
                                                        ┌─────┴─────┐ ┌─────┴─────┐
                                                        │TimescaleDB│ │   Redis   │
                                                        └───────────┘ └───────────┘
```

---

## 🛠️ Технологический стек

### Мобильное приложение
- **Framework:** Flutter 3.16+
- **State Management:** BLoC
- **Local DB:** Drift (SQLite)
- **BLE:** flutter_blue_plus
- **Charts:** fl_chart

### Backend
- **API:** FastAPI (Python 3.11)
- **WebSocket:** Go 1.21
- **ML:** scikit-learn, TensorFlow
- **Queue:** Celery + Redis
- **Database:** TimescaleDB (PostgreSQL)

### Firmware (ESP32)
- **Framework:** ESP-IDF / PlatformIO
- **Sensors:** MPU6050, DS18B20
- **Connectivity:** BLE 5.0

### Admin Panel
- **Framework:** Next.js 14
- **UI:** Tailwind CSS + shadcn/ui
- **Charts:** Recharts
- **Maps:** Leaflet

### DevOps
- **Containers:** Docker
- **Orchestration:** Kubernetes
- **CI/CD:** GitHub Actions
- **Monitoring:** Prometheus + Grafana

---

## 🚀 Быстрый старт

### Требования

- Docker & Docker Compose
- Node.js 20+ (для admin)
- Flutter 3.16+ (для mobile)
- Python 3.11+ (для backend)
- PlatformIO (для firmware)

### Запуск локального окружения

```bash
# Клонирование репозитория
git clone https://github.com/vibemon/vibemon.git
cd vibemon

# Копирование переменных окружения
cp .env.example .env

# Запуск всех сервисов
docker compose up -d

# Применение миграций БД
docker compose exec api alembic upgrade head

# Проверка
curl http://localhost:8000/health
```

### Доступ к сервисам

| Сервис | URL | Описание |
|--------|-----|----------|
| API | http://localhost:8000 | REST API |
| Admin | http://localhost:3000 | Веб-панель |
| WebSocket | ws://localhost:8080/ws | Real-time |
| Adminer | http://localhost:8081 | БД UI |
| MailHog | http://localhost:8025 | Email тест |

---

## 📱 Мобильное приложение

```bash
cd mobile

# Установка зависимостей
flutter pub get

# Запуск в режиме разработки
flutter run

# Сборка APK
flutter build apk --release

# Сборка iOS (только macOS)
flutter build ios --release
```

---

## 🔧 Прошивка ESP32

```bash
cd firmware

# Установка PlatformIO
pip install platformio

# Сборка
pio run

# Загрузка в устройство
pio run -t upload

# Мониторинг Serial
pio device monitor
```

---

## 📊 Структура проекта

```
vibemon/
├── docs/                 # Документация
├── firmware/             # Прошивка ESP32 (PlatformIO)
├── mobile/               # Мобильное приложение (Flutter)
├── backend/
│   ├── api/              # REST API (FastAPI)
│   ├── websocket/        # WebSocket сервер (Go)
│   ├── ml/               # ML сервис (Python)
│   └── worker/           # Celery workers
├── admin/                # Веб-панель (Next.js)
├── infrastructure/       # DevOps конфигурации
└── docker-compose.yml    # Локальное окружение
```

---

## 🧪 Тестирование

```bash
# Все тесты
make test

# API тесты
cd backend/api && pytest tests/ -v

# Mobile тесты
cd mobile && flutter test

# Admin тесты
cd admin && npm test
```

---

## 📈 План разработки

### Фаза 1: MVP (8 недель)
- [x] Проектирование архитектуры
- [x] BLE протокол
- [ ] Базовая прошивка ESP32
- [ ] Backend API
- [ ] Мобильное приложение (базовый функционал)

### Фаза 2: Расширение (6 недель)
- [ ] Веб-панель администратора
- [ ] ML модуль анализа аномалий
- [ ] OTA обновления
- [ ] Система уведомлений

### Фаза 3: Production (4 недели)
- [ ] DevOps, CI/CD
- [ ] Нагрузочное тестирование
- [ ] Документация
- [ ] Релиз

---

## 🤝 Участие в разработке

1. Fork репозитория
2. Создайте feature branch (`git checkout -b feature/amazing-feature`)
3. Commit изменений (`git commit -m 'Add amazing feature'`)
4. Push в branch (`git push origin feature/amazing-feature`)
5. Откройте Pull Request

---

## 📄 Лицензия

Распространяется под лицензией MIT. См. [LICENSE](LICENSE) для подробностей.

---

## 📞 Контакты

- **Email:** info@vibemon.io
- **Website:** https://vibemon.io
- **Telegram:** @vibemon_support

---

*Made with ❤️ by VibeMon Team*
