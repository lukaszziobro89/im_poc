from abc import ABC, abstractmethod


class ClassificationService(ABC):
    """Interface for document classification services."""

    def __init__(self):
        pass

    @abstractmethod
    async def classify_document(self, document_data: dict) -> dict:
        """Classify the document and return classification results."""
        pass

    @abstractmethod
    async def prepare_model_input(self, document_data: dict) -> dict:
        pass

    @abstractmethod
    async def validate_model_response(self, document_data: dict) -> dict:
        pass

