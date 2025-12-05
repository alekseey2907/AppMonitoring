"""
Telemetry model for time-series data.
"""
from datetime import datetime
from typing import TYPE_CHECKING
from uuid import UUID, uuid4

from sqlalchemy import DateTime, Float, ForeignKey, Integer, func
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.device import Device


class Telemetry(Base):
    """Telemetry model for sensor readings."""
    
    __tablename__ = "telemetry"
    
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
    
    # Timestamp
    recorded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        index=True,
    )
    
    # Accelerometer data (g)
    accel_x: Mapped[float] = mapped_column(Float)
    accel_y: Mapped[float] = mapped_column(Float)
    accel_z: Mapped[float] = mapped_column(Float)
    
    # Gyroscope data (deg/s)
    gyro_x: Mapped[float] = mapped_column(Float, default=0)
    gyro_y: Mapped[float] = mapped_column(Float, default=0)
    gyro_z: Mapped[float] = mapped_column(Float, default=0)
    
    # Calculated vibration metrics
    vibration_rms: Mapped[float] = mapped_column(Float)
    vibration_peak: Mapped[float] = mapped_column(Float)
    
    # Temperature (°C)
    temperature: Mapped[float] = mapped_column(Float)
    
    # Battery
    battery_level: Mapped[int] = mapped_column(Integer)  # 0-100%
    battery_voltage: Mapped[float] = mapped_column(Float, default=0)
    
    # Alert flags
    alert_flags: Mapped[int] = mapped_column(Integer, default=0)
    
    # Relationships
    device: Mapped["Device"] = relationship(
        "Device",
        back_populates="telemetry",
    )
    
    def __repr__(self) -> str:
        return f"<Telemetry {self.device_id} @ {self.recorded_at}>"
