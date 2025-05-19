# input_management/schemas/requests.py
from pydantic import BaseModel, Field
from typing import Dict, Any, Optional

class BaseRequest(BaseModel):
    """Base class for all request models."""
    request_id: str = Field(..., description="Unique identifier for the request")

class ClassificationRequest(BaseRequest):
    """Request model for classification."""
    content: Dict[str, Any] = Field(..., description="Content to classify")
    options: Optional[Dict[str, Any]] = Field(None, description="Classification options")