# input_management/schemas/responses.py
from pydantic import BaseModel, Field
from typing import Dict, Any, Optional, List

class BaseResponse(BaseModel):
    """Base class for all response models."""
    request_id: str = Field(..., description="Unique identifier for the request")
    success: bool = Field(..., description="Whether the request was successful")

class ErrorResponse(BaseResponse):
    """Response model for errors."""
    success: bool = Field(False, description="Always False for error responses")
    error_code: str = Field(..., description="Error code")
    error_message: str = Field(..., description="Error message")
    error_details: Optional[Dict[str, Any]] = Field(None, description="Additional error details")

class ClassificationResponse(BaseResponse):
    """Response model for classification."""
    success: bool = Field(True, description="Always True for successful responses")
    classification_result: Dict[str, Any] = Field(..., description="Classification result")
    confidence: float = Field(..., description="Confidence score", ge=0.0, le=1.0)

class HealthResponse(BaseModel):
    """Response model for health check."""
    status: str = Field(..., description="Service status")
    version: str = Field(..., description="Service version")