# Структура проекта VibeMon

## Общая структура репозитория

```
vibemon/
├── README.md
├── LICENSE
├── .gitignore
├── docker-compose.yml
├── docker-compose.prod.yml
├── Makefile
│
├── docs/                           # Документация
│   ├── 01-TECHNICAL_SPECIFICATION.md
│   ├── 02-ARCHITECTURE.md
│   ├── 03-BLE_PROTOCOL.md
│   ├── 04-DATABASE_SCHEMA.md
│   ├── 05-API_SPECIFICATION.md
│   ├── 06-PROJECT_STRUCTURE.md
│   ├── 07-BUSINESS_PLAN.md
│   ├── diagrams/
│   │   ├── architecture.drawio
│   │   ├── ble-protocol.drawio
│   │   └── er-diagram.drawio
│   └── images/
│       └── ...
│
├── firmware/                       # Прошивка ESP32
│   ├── README.md
│   ├── platformio.ini
│   ├── sdkconfig.defaults
│   ├── partitions.csv
│   │
│   ├── src/
│   │   ├── main.cpp
│   │   ├── config.h
│   │   │
│   │   ├── ble/
│   │   │   ├── ble_manager.h
│   │   │   ├── ble_manager.cpp
│   │   │   ├── ble_services.h
│   │   │   ├── ble_services.cpp
│   │   │   ├── ble_ota.h
│   │   │   └── ble_ota.cpp
│   │   │
│   │   ├── sensors/
│   │   │   ├── mpu6050.h
│   │   │   ├── mpu6050.cpp
│   │   │   ├── ds18b20.h
│   │   │   ├── ds18b20.cpp
│   │   │   └── sensor_manager.h
│   │   │
│   │   ├── data/
│   │   │   ├── data_packet.h
│   │   │   ├── data_buffer.h
│   │   │   ├── data_buffer.cpp
│   │   │   └── fft_analyzer.h
│   │   │
│   │   ├── power/
│   │   │   ├── power_manager.h
│   │   │   ├── power_manager.cpp
│   │   │   └── sleep_modes.h
│   │   │
│   │   ├── storage/
│   │   │   ├── nvs_storage.h
│   │   │   ├── nvs_storage.cpp
│   │   │   └── config_manager.h
│   │   │
│   │   ├── ota/
│   │   │   ├── ota_manager.h
│   │   │   ├── ota_manager.cpp
│   │   │   └── ota_web.cpp
│   │   │
│   │   └── utils/
│   │       ├── led_indicator.h
│   │       ├── led_indicator.cpp
│   │       ├── button_handler.h
│   │       └── debug_log.h
│   │
│   ├── lib/
│   │   └── .gitkeep
│   │
│   ├── include/
│   │   └── .gitkeep
│   │
│   └── test/
│       ├── test_mpu6050.cpp
│       ├── test_ble.cpp
│       └── test_data_packet.cpp
│
├── mobile/                         # Мобильное приложение Flutter
│   ├── README.md
│   ├── pubspec.yaml
│   ├── analysis_options.yaml
│   │
│   ├── android/
│   │   ├── app/
│   │   │   ├── build.gradle
│   │   │   └── src/main/
│   │   │       ├── AndroidManifest.xml
│   │   │       └── kotlin/
│   │   ├── build.gradle
│   │   └── settings.gradle
│   │
│   ├── ios/
│   │   ├── Runner/
│   │   │   ├── Info.plist
│   │   │   └── AppDelegate.swift
│   │   ├── Podfile
│   │   └── Runner.xcworkspace/
│   │
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   │
│   │   ├── core/
│   │   │   ├── constants/
│   │   │   │   ├── app_constants.dart
│   │   │   │   ├── ble_uuids.dart
│   │   │   │   └── api_endpoints.dart
│   │   │   │
│   │   │   ├── theme/
│   │   │   │   ├── app_theme.dart
│   │   │   │   ├── colors.dart
│   │   │   │   └── typography.dart
│   │   │   │
│   │   │   ├── utils/
│   │   │   │   ├── extensions.dart
│   │   │   │   ├── validators.dart
│   │   │   │   └── formatters.dart
│   │   │   │
│   │   │   └── errors/
│   │   │       ├── failures.dart
│   │   │       └── exceptions.dart
│   │   │
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── local/
│   │   │   │   │   ├── database.dart
│   │   │   │   │   ├── database.g.dart
│   │   │   │   │   ├── tables/
│   │   │   │   │   │   ├── devices_table.dart
│   │   │   │   │   │   ├── telemetry_table.dart
│   │   │   │   │   │   └── settings_table.dart
│   │   │   │   │   └── daos/
│   │   │   │   │       ├── device_dao.dart
│   │   │   │   │       └── telemetry_dao.dart
│   │   │   │   │
│   │   │   │   └── remote/
│   │   │   │       ├── api_client.dart
│   │   │   │       ├── auth_api.dart
│   │   │   │       ├── device_api.dart
│   │   │   │       ├── telemetry_api.dart
│   │   │   │       └── websocket_client.dart
│   │   │   │
│   │   │   ├── models/
│   │   │   │   ├── device_model.dart
│   │   │   │   ├── telemetry_model.dart
│   │   │   │   ├── alert_model.dart
│   │   │   │   ├── user_model.dart
│   │   │   │   └── ble_packet_model.dart
│   │   │   │
│   │   │   └── repositories/
│   │   │       ├── auth_repository_impl.dart
│   │   │       ├── device_repository_impl.dart
│   │   │       ├── telemetry_repository_impl.dart
│   │   │       └── sync_repository_impl.dart
│   │   │
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── device.dart
│   │   │   │   ├── telemetry.dart
│   │   │   │   ├── alert.dart
│   │   │   │   └── user.dart
│   │   │   │
│   │   │   ├── repositories/
│   │   │   │   ├── auth_repository.dart
│   │   │   │   ├── device_repository.dart
│   │   │   │   ├── telemetry_repository.dart
│   │   │   │   └── sync_repository.dart
│   │   │   │
│   │   │   └── usecases/
│   │   │       ├── auth/
│   │   │       │   ├── login_usecase.dart
│   │   │       │   ├── logout_usecase.dart
│   │   │       │   └── register_usecase.dart
│   │   │       │
│   │   │       ├── device/
│   │   │       │   ├── get_devices_usecase.dart
│   │   │       │   ├── connect_device_usecase.dart
│   │   │       │   └── update_firmware_usecase.dart
│   │   │       │
│   │   │       └── telemetry/
│   │   │           ├── get_telemetry_usecase.dart
│   │   │           └── sync_telemetry_usecase.dart
│   │   │
│   │   ├── presentation/
│   │   │   ├── blocs/
│   │   │   │   ├── auth/
│   │   │   │   │   ├── auth_bloc.dart
│   │   │   │   │   ├── auth_event.dart
│   │   │   │   │   └── auth_state.dart
│   │   │   │   │
│   │   │   │   ├── device/
│   │   │   │   │   ├── device_bloc.dart
│   │   │   │   │   ├── device_event.dart
│   │   │   │   │   └── device_state.dart
│   │   │   │   │
│   │   │   │   ├── ble/
│   │   │   │   │   ├── ble_bloc.dart
│   │   │   │   │   ├── ble_event.dart
│   │   │   │   │   └── ble_state.dart
│   │   │   │   │
│   │   │   │   ├── telemetry/
│   │   │   │   │   └── telemetry_bloc.dart
│   │   │   │   │
│   │   │   │   └── sync/
│   │   │   │       └── sync_bloc.dart
│   │   │   │
│   │   │   ├── screens/
│   │   │   │   ├── splash/
│   │   │   │   │   └── splash_screen.dart
│   │   │   │   │
│   │   │   │   ├── auth/
│   │   │   │   │   ├── login_screen.dart
│   │   │   │   │   └── register_screen.dart
│   │   │   │   │
│   │   │   │   ├── dashboard/
│   │   │   │   │   ├── dashboard_screen.dart
│   │   │   │   │   └── widgets/
│   │   │   │   │       ├── device_card.dart
│   │   │   │   │       ├── stats_card.dart
│   │   │   │   │       └── alert_banner.dart
│   │   │   │   │
│   │   │   │   ├── devices/
│   │   │   │   │   ├── devices_list_screen.dart
│   │   │   │   │   ├── device_detail_screen.dart
│   │   │   │   │   ├── device_scan_screen.dart
│   │   │   │   │   └── widgets/
│   │   │   │   │       ├── device_tile.dart
│   │   │   │   │       └── connection_status.dart
│   │   │   │   │
│   │   │   │   ├── charts/
│   │   │   │   │   ├── realtime_chart_screen.dart
│   │   │   │   │   ├── history_chart_screen.dart
│   │   │   │   │   └── widgets/
│   │   │   │   │       ├── vibration_chart.dart
│   │   │   │   │       ├── temperature_chart.dart
│   │   │   │   │       └── fft_chart.dart
│   │   │   │   │
│   │   │   │   ├── diagnostics/
│   │   │   │   │   ├── diagnostics_screen.dart
│   │   │   │   │   └── widgets/
│   │   │   │   │       ├── sensor_status.dart
│   │   │   │   │       └── ble_info.dart
│   │   │   │   │
│   │   │   │   ├── ota/
│   │   │   │   │   ├── ota_screen.dart
│   │   │   │   │   └── widgets/
│   │   │   │   │       └── progress_indicator.dart
│   │   │   │   │
│   │   │   │   ├── alerts/
│   │   │   │   │   ├── alerts_screen.dart
│   │   │   │   │   └── alert_detail_screen.dart
│   │   │   │   │
│   │   │   │   └── settings/
│   │   │   │       ├── settings_screen.dart
│   │   │   │       ├── thresholds_screen.dart
│   │   │   │       └── profile_screen.dart
│   │   │   │
│   │   │   └── widgets/
│   │   │       ├── common/
│   │   │       │   ├── loading_indicator.dart
│   │   │       │   ├── error_widget.dart
│   │   │       │   └── empty_state.dart
│   │   │       │
│   │   │       └── charts/
│   │   │           ├── line_chart_widget.dart
│   │   │           └── gauge_widget.dart
│   │   │
│   │   ├── services/
│   │   │   ├── ble/
│   │   │   │   ├── ble_service.dart
│   │   │   │   ├── ble_device.dart
│   │   │   │   ├── ble_parser.dart
│   │   │   │   └── ble_ota_service.dart
│   │   │   │
│   │   │   ├── sync/
│   │   │   │   ├── sync_service.dart
│   │   │   │   └── conflict_resolver.dart
│   │   │   │
│   │   │   ├── notifications/
│   │   │   │   ├── notification_service.dart
│   │   │   │   └── push_handler.dart
│   │   │   │
│   │   │   └── background/
│   │   │       └── background_service.dart
│   │   │
│   │   └── di/
│   │       └── injection.dart
│   │
│   └── test/
│       ├── unit/
│       │   ├── blocs/
│       │   ├── repositories/
│       │   └── usecases/
│       │
│       ├── widget/
│       │   └── screens/
│       │
│       └── integration/
│           └── ble_integration_test.dart
│
├── backend/                        # Серверная часть
│   ├── README.md
│   │
│   ├── api/                        # FastAPI REST API
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   ├── pyproject.toml
│   │   │
│   │   ├── app/
│   │   │   ├── __init__.py
│   │   │   ├── main.py
│   │   │   ├── config.py
│   │   │   │
│   │   │   ├── api/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── deps.py
│   │   │   │   │
│   │   │   │   └── v1/
│   │   │   │       ├── __init__.py
│   │   │   │       ├── router.py
│   │   │   │       ├── auth.py
│   │   │   │       ├── users.py
│   │   │   │       ├── devices.py
│   │   │   │       ├── telemetry.py
│   │   │   │       ├── alerts.py
│   │   │   │       ├── firmware.py
│   │   │   │       ├── analytics.py
│   │   │   │       └── reports.py
│   │   │   │
│   │   │   ├── core/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── security.py
│   │   │   │   ├── exceptions.py
│   │   │   │   └── logging.py
│   │   │   │
│   │   │   ├── db/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── session.py
│   │   │   │   ├── base.py
│   │   │   │   └── migrations/
│   │   │   │       └── versions/
│   │   │   │
│   │   │   ├── models/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── user.py
│   │   │   │   ├── organization.py
│   │   │   │   ├── device.py
│   │   │   │   ├── telemetry.py
│   │   │   │   ├── alert.py
│   │   │   │   └── firmware.py
│   │   │   │
│   │   │   ├── schemas/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── user.py
│   │   │   │   ├── device.py
│   │   │   │   ├── telemetry.py
│   │   │   │   ├── alert.py
│   │   │   │   └── common.py
│   │   │   │
│   │   │   ├── services/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── auth_service.py
│   │   │   │   ├── device_service.py
│   │   │   │   ├── telemetry_service.py
│   │   │   │   ├── alert_service.py
│   │   │   │   └── firmware_service.py
│   │   │   │
│   │   │   ├── repositories/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── base.py
│   │   │   │   ├── user_repo.py
│   │   │   │   ├── device_repo.py
│   │   │   │   └── telemetry_repo.py
│   │   │   │
│   │   │   └── utils/
│   │   │       ├── __init__.py
│   │   │       └── helpers.py
│   │   │
│   │   ├── tests/
│   │   │   ├── __init__.py
│   │   │   ├── conftest.py
│   │   │   ├── test_auth.py
│   │   │   ├── test_devices.py
│   │   │   └── test_telemetry.py
│   │   │
│   │   └── alembic.ini
│   │
│   ├── websocket/                  # Go WebSocket Server
│   │   ├── Dockerfile
│   │   ├── go.mod
│   │   ├── go.sum
│   │   │
│   │   ├── cmd/
│   │   │   └── server/
│   │   │       └── main.go
│   │   │
│   │   ├── internal/
│   │   │   ├── config/
│   │   │   │   └── config.go
│   │   │   │
│   │   │   ├── hub/
│   │   │   │   ├── hub.go
│   │   │   │   ├── client.go
│   │   │   │   └── message.go
│   │   │   │
│   │   │   ├── handler/
│   │   │   │   └── websocket.go
│   │   │   │
│   │   │   ├── redis/
│   │   │   │   └── pubsub.go
│   │   │   │
│   │   │   └── auth/
│   │   │       └── jwt.go
│   │   │
│   │   └── pkg/
│   │       └── logger/
│   │           └── logger.go
│   │
│   ├── ml/                         # ML Service
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   │
│   │   ├── app/
│   │   │   ├── __init__.py
│   │   │   ├── main.py
│   │   │   ├── config.py
│   │   │   │
│   │   │   ├── models/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── anomaly_detector.py
│   │   │   │   ├── predictive_model.py
│   │   │   │   └── fft_analyzer.py
│   │   │   │
│   │   │   ├── services/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── training_service.py
│   │   │   │   └── inference_service.py
│   │   │   │
│   │   │   └── tasks/
│   │   │       ├── __init__.py
│   │   │       ├── analyze_task.py
│   │   │       └── train_task.py
│   │   │
│   │   └── models/
│   │       └── .gitkeep
│   │
│   └── worker/                     # Celery Worker
│       ├── Dockerfile
│       ├── requirements.txt
│       │
│       ├── app/
│       │   ├── __init__.py
│       │   ├── celery_app.py
│       │   ├── config.py
│       │   │
│       │   └── tasks/
│       │       ├── __init__.py
│       │       ├── notifications.py
│       │       ├── alerts.py
│       │       └── reports.py
│       │
│       └── templates/
│           ├── email/
│           │   ├── alert.html
│           │   └── report.html
│           │
│           └── telegram/
│               └── alert.md
│
├── admin/                          # Веб-панель администратора
│   ├── README.md
│   ├── package.json
│   ├── package-lock.json
│   ├── next.config.js
│   ├── tsconfig.json
│   ├── tailwind.config.js
│   ├── postcss.config.js
│   │
│   ├── public/
│   │   ├── favicon.ico
│   │   └── images/
│   │
│   ├── src/
│   │   ├── app/
│   │   │   ├── layout.tsx
│   │   │   ├── page.tsx
│   │   │   ├── globals.css
│   │   │   │
│   │   │   ├── (auth)/
│   │   │   │   ├── login/
│   │   │   │   │   └── page.tsx
│   │   │   │   └── layout.tsx
│   │   │   │
│   │   │   └── (dashboard)/
│   │   │       ├── layout.tsx
│   │   │       ├── dashboard/
│   │   │       │   └── page.tsx
│   │   │       ├── devices/
│   │   │       │   ├── page.tsx
│   │   │       │   └── [id]/
│   │   │       │       └── page.tsx
│   │   │       ├── alerts/
│   │   │       │   └── page.tsx
│   │   │       ├── analytics/
│   │   │       │   └── page.tsx
│   │   │       ├── map/
│   │   │       │   └── page.tsx
│   │   │       ├── users/
│   │   │       │   └── page.tsx
│   │   │       ├── firmware/
│   │   │       │   └── page.tsx
│   │   │       └── settings/
│   │   │           └── page.tsx
│   │   │
│   │   ├── components/
│   │   │   ├── ui/
│   │   │   │   ├── button.tsx
│   │   │   │   ├── card.tsx
│   │   │   │   ├── input.tsx
│   │   │   │   ├── table.tsx
│   │   │   │   ├── modal.tsx
│   │   │   │   └── ...
│   │   │   │
│   │   │   ├── layout/
│   │   │   │   ├── sidebar.tsx
│   │   │   │   ├── header.tsx
│   │   │   │   └── footer.tsx
│   │   │   │
│   │   │   ├── charts/
│   │   │   │   ├── line-chart.tsx
│   │   │   │   ├── gauge-chart.tsx
│   │   │   │   └── heatmap.tsx
│   │   │   │
│   │   │   ├── map/
│   │   │   │   ├── device-map.tsx
│   │   │   │   └── device-marker.tsx
│   │   │   │
│   │   │   └── devices/
│   │   │       ├── device-card.tsx
│   │   │       ├── device-table.tsx
│   │   │       └── telemetry-panel.tsx
│   │   │
│   │   ├── lib/
│   │   │   ├── api.ts
│   │   │   ├── auth.ts
│   │   │   ├── websocket.ts
│   │   │   └── utils.ts
│   │   │
│   │   ├── hooks/
│   │   │   ├── useAuth.ts
│   │   │   ├── useDevices.ts
│   │   │   ├── useTelemetry.ts
│   │   │   └── useWebSocket.ts
│   │   │
│   │   ├── store/
│   │   │   ├── index.ts
│   │   │   ├── authSlice.ts
│   │   │   ├── deviceSlice.ts
│   │   │   └── alertSlice.ts
│   │   │
│   │   └── types/
│   │       ├── index.ts
│   │       ├── device.ts
│   │       ├── telemetry.ts
│   │       └── user.ts
│   │
│   └── tests/
│       └── ...
│
├── infrastructure/                 # DevOps и инфраструктура
│   ├── docker/
│   │   ├── api.Dockerfile
│   │   ├── websocket.Dockerfile
│   │   ├── ml.Dockerfile
│   │   ├── worker.Dockerfile
│   │   └── admin.Dockerfile
│   │
│   ├── kubernetes/
│   │   ├── namespace.yaml
│   │   ├── configmap.yaml
│   │   ├── secrets.yaml
│   │   │
│   │   ├── api/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── hpa.yaml
│   │   │
│   │   ├── websocket/
│   │   │   ├── deployment.yaml
│   │   │   └── service.yaml
│   │   │
│   │   ├── ml/
│   │   │   └── deployment.yaml
│   │   │
│   │   ├── worker/
│   │   │   └── deployment.yaml
│   │   │
│   │   ├── admin/
│   │   │   ├── deployment.yaml
│   │   │   └── service.yaml
│   │   │
│   │   ├── database/
│   │   │   ├── timescaledb-statefulset.yaml
│   │   │   └── redis-statefulset.yaml
│   │   │
│   │   ├── ingress/
│   │   │   └── traefik-ingress.yaml
│   │   │
│   │   └── monitoring/
│   │       ├── prometheus/
│   │       ├── grafana/
│   │       └── loki/
│   │
│   ├── terraform/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   │
│   │   ├── modules/
│   │   │   ├── vpc/
│   │   │   ├── kubernetes/
│   │   │   └── database/
│   │   │
│   │   └── environments/
│   │       ├── dev/
│   │       ├── staging/
│   │       └── prod/
│   │
│   └── scripts/
│       ├── setup.sh
│       ├── deploy.sh
│       └── backup.sh
│
└── .github/                        # GitHub Actions CI/CD
    └── workflows/
        ├── ci.yml
        ├── cd-staging.yml
        ├── cd-production.yml
        ├── firmware-build.yml
        ├── mobile-build.yml
        └── release.yml
```

---

## Описание ключевых директорий

### firmware/
Прошивка ESP32 на PlatformIO (ESP-IDF framework). Содержит код для работы с датчиками, BLE, управления питанием и OTA.

### mobile/
Кроссплатформенное мобильное приложение на Flutter с Clean Architecture. Использует BLoC для state management и Drift для локальной БД.

### backend/api/
REST API на FastAPI (Python). Основной сервер для обработки запросов, авторизации и бизнес-логики.

### backend/websocket/
WebSocket сервер на Go для real-time обновлений. Высокопроизводительная обработка множественных подключений.

### backend/ml/
Сервис машинного обучения для анализа аномалий и предиктивной диагностики.

### backend/worker/
Celery воркеры для фоновых задач: уведомления, отчёты, периодический анализ.

### admin/
Веб-панель администратора на Next.js 14 с App Router. Использует Tailwind CSS и Recharts для графиков.

### infrastructure/
Конфигурации для развёртывания: Docker, Kubernetes, Terraform, мониторинг.

---

*Документ: Структура проекта VibeMon v1.0*
