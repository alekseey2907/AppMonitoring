"""
Alert model.
"""
from datetime import datetime
from typing import TYPE_CHECKING, Optional
from uuid import UUID, uuid4

from sqlalchemy import DateTime, Float, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.device import Device


class Alert(Base):
    """Alert model."""
    
    __tablename__ = "alerts"
    
    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    device_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("devices.id"),
        index=True,
    )
    
    # Alert type: vibration_warning, vibration_critical, temp_warning, temp_critical, battery_low
    alert_type: Mapped[str] = mapped_column(String(50))
    
    # Severity: info, warning, critical
    severity: Mapped[str] = mapped_column(String(20))
    
    # Status: active, acknowledged, resolved
    status: Mapped[str] = mapped_column(String(20), default="active")
    
    # Alert details
    title: Mapped[str] = mapped_column(String(200))
    message: Mapped[str] = mapped_column(String(1000))
    
    # Measured value that triggered the alert
    measured_value: Mapped[float] = mapped_column(Float)
    threshold_value: Mapped[float] = mapped_column(Float)
    
    # Resolution
    acknowledged_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    acknowledged_by: Mapped[Optional[UUID]] = mapped_column(
        PGUUID(as_uuid=True),
        nullable=True,
    )
    resolved_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    resolved_by: Mapped[Optional[UUID]] = mapped_column(
        PGUUID(as_uuid=True),
        nullable=True,
    )
    resolution_note: Mapped[Optional[str]] = mapped_column(String(1000), nullable=True)
    
    # Timestamps
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    
    # Relationships
    device: Mapped["Device"] = relationship(
        "Device",
        back_populates="alerts",
    )
    
    def __repr__(self) -> str:
        return f"<Alert {self.alert_type} - {self.status}>"
