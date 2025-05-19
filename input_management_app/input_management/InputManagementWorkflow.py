from enum import Enum
from typing import Optional
from pydantic import BaseModel
from common.logging.custom_logger import CustomLogger
from temp.service import StorageService
from temp.service.ClassificationService import ClassificationService
from temp.service.OcrService import OcrService
from temp.service.RequestStoreService import RequestStoreService


class JobStatus(Enum):
    PENDING = "PENDING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"

class InputManagementWorkflow:
    """
    Manages document processing workflows while delegating actual work to injected services.
    """

    def __init__(
            self,
            extraction_service,
            classification_service: ClassificationService,
            storage_service: StorageService,
            ocr_service: OcrService,
            request_store_service: RequestStoreService,
            logger: Optional[CustomLogger] = None
    ):
        """Initialize a workflow with required services."""
        self.extraction_service = extraction_service
        self.classification_service = classification_service
        self.storage_service = storage_service
        self.ocr_service = ocr_service
        self.request_store_service = request_store_service
        self.logger = logger

    async def perform_classification(self, request_id: str, document_data: dict) -> dict:
        """Orchestrate a full document processing workflow."""
        if self.logger:
            self.logger.info(f"Starting document processing workflow for request: {request_id}")


        # Step 1: OCR
        self.logger.info("Starting OCR processing")
        await self.request_store_service.put(request_id)
        ocr_result = await self.ocr_service.perform_ocr(document_data)
        is_valid = self.ocr_service.validate_ocr_response(ocr_result)
        if is_valid:
            await self.request_store_service.update(request_id, JobStatus.PENDING.value)
            self.logger.info("OCR completed")
        else:
            await self.request_store_service.update(request_id, JobStatus.FAILED.value)
            self.logger.info("OCR failed")

        # Step 2: Classification
        self.logger.info("Starting Classification ")
        await self.request_store_service.update(request_id, JobStatus.PENDING.value)
        classification_result = await self.classification_service.classify_document(document_data)
        await self.request_store_service.update(request_id, JobStatus.PENDING.value)
        self.logger.info("Classification completed")

        # Step 3: Storage files/results
        self.logger.info("Starting storing result")
        await self.request_store_service.update(request_id, JobStatus.PENDING.value)
        await self.storage_service.store_document(document_data)
        self.logger.info("stored completed")

        if self.logger:
            self.logger.info(f"Document workflow completed for request: {request_id}")

        return {
            "request_id": request_id,
            "status": "completed",
        }

    async def perform_pre_validation(self):
        pass

    async def perform_post_validation(self):
        pass

    async def perform_ocr(self, document_data: dict) -> dict:
        """Perform OCR on the document data."""
        if self.logger:
            self.logger.info("Starting OCR processing")

        ocr_result = await self.ocr_service.perform_ocr(document_data)
        is_valid = self.ocr_service.validate_ocr_response(ocr_result)

        if is_valid:
            self.logger.info("OCR completed successfully")
        else:
            self.logger.error("OCR failed")

        return ocr_result

    async def perform_manualfeedback(self, document_data: dict) -> dict:
        pass