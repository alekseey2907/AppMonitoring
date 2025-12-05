"""Alerts endpoints."""
from fastapi import APIRouter
router = APIRouter()

@router.get("")
async def list_alerts() -> dict:
    return {"alerts": []}

@router.post("/{alert_id}/acknowledge")
async def acknowledge_alert(alert_id: str) -> dict:
    return {"status": "acknowledged"}

@router.post("/{alert_id}/resolve")
async def resolve_alert(alert_id: str) -> dict:
    return {"status": "resolved"}
