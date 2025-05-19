# input_management/api/workflow.py
from fastapi import APIRouter, Depends, Header, Body, HTTPException
from typing import Dict, Any, Optional
import uuid

from input_management_app.input_management.schemas import ClassificationResponse
from temp.InputManagementWorkflow import InputManagementWorkflow


def create_request_router(
        workflow: Optional[InputManagementWorkflow] = None,
        prefix: str = "/api"
) -> APIRouter:

    router = APIRouter(prefix=f"{prefix}/request", tags=["request"])

    async def get_workflow_instance() -> InputManagementWorkflow:
        """Dependency to get workflow instance."""
        if workflow is None:
            raise HTTPException(status_code=500, detail="Workflow not configured")
        return workflow

    @router.post("/request", response_model=ClassificationResponse)
    async def process_document(
            document_data: Dict[str, Any] = Body(...),
            workflow: InputManagementWorkflow = Depends(get_workflow_instance),
            x_request_id: Optional[str] = Header(None),
    ):
        """Process and classify a document."""
        request_id = x_request_id or str(uuid.uuid4())

        if workflow.logger:
            workflow.logger.info(f"Received classification request: {request_id}")

        result = await workflow.perform_classification(request_id, document_data)

        # Return formatted response
        return ClassificationResponse(
            request_id=request_id,
            success=True,
            classification_result=result,
            confidence=1.0  # Set appropriate confidence value from result
        )

    @router.post("/request/feedback", response_model=BaseResponse)
    async def process_feedback(
            feedback_data: Dict[str, Any] = Body(...),
            workflow: InputManagementWorkflow = Depends(get_workflow_instance),
            x_request_id: Optional[str] = Header(None),
    ):
        """Process manual feedback for a document."""
        request_id = x_request_id or str(uuid.uuid4())

        if workflow.logger:
            workflow.logger.info(f"Received feedback request: {request_id}")

        await workflow.perform_manualfeedback(feedback_data)

        return BaseResponse(
            request_id=request_id,
            success=True
        )

    return router