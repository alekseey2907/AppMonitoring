"""
Device model.
"""
from datetime import datetime
from typing import TYPE_CHECKING, List, Optional
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.organization import Organization
    from app.models.telemetry import Telemetry
    from app.models.alert import Alert
    from app.models.threshold import Threshold


class Device(Base):
    """Device model."""
    
    __tablename__ = "devices"
    
    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    mac_address: Mapped[str] = mapped_column(String(17), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(100))
    description: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    
    # Device type: tractor, elevator, pump, motor, etc.
    device_type: Mapped[str] = mapped_column(String(50), default="generic")
    
    # Status
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_online: Mapped[bool] = mapped_column(Boolean, default=False)
    
    # Firmware
    firmware_version: Mapped[str] = mapped_column(String(20), default="1.0.0")
    
    # Location
    latitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    longitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    location_name: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    
    # Configuration
    sample_interval_ms: Mapped[int] = mapped_column(Integer, default=1000)
    
    # Organization
    organization_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("organizations.id"),
    )
    
    # Timestamps
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
    last_seen: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    
    # Relationships
    organization: Mapped["Organization"] = relationship(
        "Organization",
        back_populates="devices",
    )
    telemetry: Mapped[List["Telemetry"]] = relationship(
        "Telemetry",
        back_populates="device",
    )
    alerts: Mapped[List["Alert"]] = relationship(
        "Alert",
        back_populates="device",
    )
    thresholds: Mapped[Optional["Threshold"]] = relationship(
        "Threshold",
        back_populates="device",
        uselist=False,
    )
    
    def __repr__(self) -> str:
        return f"<Device {self.name} ({self.mac_address})>"
