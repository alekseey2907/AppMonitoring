"""
API v1 router.
"""
from fastapi import APIRouter

from app.api.v1.endpoints import auth, devices, telemetry, alerts, analytics, firmwares

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(devices.router, prefix="/devices", tags=["Devices"])
api_router.include_router(telemetry.router, prefix="/telemetry", tags=["Telemetry"])
api_router.include_router(alerts.router, prefix="/alerts", tags=["Alerts"])
api_router.include_router(analytics.router, prefix="/analytics", tags=["Analytics"])
api_router.include_router(firmwares.router, prefix="/firmwares", tags=["Firmware OTA"])
