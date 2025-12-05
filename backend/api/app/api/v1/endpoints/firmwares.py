"""Firmware OTA endpoints."""
from fastapi import APIRouter
router = APIRouter()

@router.get("/check")
async def check_update(device_id: str, current_version: str) -> dict:
    return {"update_available": False}

@router.get("/{firmware_id}/download")
async def download_firmware(firmware_id: str) -> dict:
    return {"url": ""}
