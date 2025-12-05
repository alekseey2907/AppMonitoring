"""Telemetry endpoints."""
from fastapi import APIRouter
router = APIRouter()

@router.post("/{device_id}")
async def send_telemetry(device_id: str) -> dict:
    return {"status": "ok"}

@router.get("/{device_id}")
async def get_telemetry(device_id: str) -> dict:
    return {"device_id": device_id, "data": []}
