"""
Pydantic schemas for authentication.
"""
from typing import Optional

from pydantic import BaseModel, EmailStr


class UserCreate(BaseModel):
    """Schema for user registration."""
    email: EmailStr
    password: str
    name: str
    phone: Optional[str] = None


class UserResponse(BaseModel):
    """Schema for user response."""
    id: str
    email: str
    name: str
    phone: Optional[str]
    role: str
    is_active: bool
    
    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    """Schema for token response."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
