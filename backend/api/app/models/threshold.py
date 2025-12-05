"""
Threshold model for device alert thresholds.
"""
from datetime import datetime
from typing import TYPE_CHECKING
from uuid import UUID, uuid4

from sqlalchemy import DateTime, Float, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.device import Device


class Threshold(Base):
    """Threshold model for device-specific alert thresholds."""
    
    __tablename__ = "thresholds"
    
    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    device_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("devices.id"),
        unique=True,
    )
    
    # Vibration thresholds (g)
    vibration_warning: Mapped[float] = mapped_column(Float, default=2.0)
    vibration_critical: Mapped[float] = mapped_column(Float, default=4.0)
    
    # Temperature thresholds (°C)
    temp_warning: Mapped[float] = mapped_column(Float, default=60.0)
    temp_critical: Mapped[float] = mapped_column(Float, default=80.0)
    
    # Battery threshold (%)
    battery_low: Mapped[int] = mapped_column(default=20)
    
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
    
    # Relationships
    device: Mapped["Device"] = relationship(
        "Device",
        back_populates="thresholds",
    )
    
    def __repr__(self) -> str:
        return f"<Threshold for device {self.device_id}>"
