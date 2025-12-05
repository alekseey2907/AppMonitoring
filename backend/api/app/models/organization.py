"""
Organization model.
"""
from datetime import datetime
from typing import TYPE_CHECKING, List, Optional
from uuid import UUID, uuid4

from sqlalchemy import DateTime, String, func
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.device import Device


class Organization(Base):
    """Organization model."""
    
    __tablename__ = "organizations"
    
    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )
    name: Mapped[str] = mapped_column(String(200))
    description: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    
    # Subscription tier: starter, professional, enterprise
    tier: Mapped[str] = mapped_column(String(20), default="starter")
    max_devices: Mapped[int] = mapped_column(default=10)
    
    # Contact info
    contact_email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    contact_phone: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    address: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    
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
    users: Mapped[List["User"]] = relationship(
        "User",
        back_populates="organization",
    )
    devices: Mapped[List["Device"]] = relationship(
        "Device",
        back_populates="organization",
    )
    
    def __repr__(self) -> str:
        return f"<Organization {self.name}>"
