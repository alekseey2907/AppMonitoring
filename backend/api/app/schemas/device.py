"""
Pydantic schemas for devices.
"""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel


class DeviceCreate(BaseModel):
    """Schema for device creation."""
    mac_address: str
    name: str
    description: Optional[str] = None
    device_type: str = "generic"
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    location_name: Optional[str] = None
    organization_id: UUID


class DeviceUpdate(BaseModel):
    """Schema for device update."""
    name: Optional[str] = None
    description: Optional[str] = None
    device_type: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    location_name: Optional[str] = None
    sample_interval_ms: Optional[int] = None
    is_active: Optional[bool] = None


class DeviceResponse(BaseModel):
    """Schema for device response."""
    id: UUID
    mac_address: str
    name: str
    description: Optional[str]
    device_type: str
    is_active: bool
    is_online: bool
    firmware_version: str
    latitude: Optional[float]
    longitude: Optional[float]
    location_name: Optional[str]
    sample_interval_ms: int
    organization_id: UUID
    created_at: datetime
    updated_at: datetime
    last_seen: Optional[datetime]
    
    class Config:
        from_attributes = True
