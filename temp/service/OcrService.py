from abc import ABC, abstractmethod


class OcrService(ABC):

    def __init__(self):
        pass

    @abstractmethod
    async def perform_ocr(self, document_data: dict) -> dict:
        pass

    @abstractmethod
    async def validate_ocr_response(self, document_data: dict) -> bool:
        pass

