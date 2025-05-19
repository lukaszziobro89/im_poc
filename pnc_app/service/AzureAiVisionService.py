from temp.service.OcrService import OcrService


class AzureAiVisionService(OcrService):
    async def perform_ocr(self, document_data: dict) -> dict:
        print(f"AzureAiVisionService: perform_ocr called with document_data: {document_data}")
        return {
            "text": "Sample OCR text",
            "language": "en"
        }

    async def validate_ocr_response(self, document_data: dict) -> bool:
        print(f"AzureAiVisionService: validate_ocr_response called with document_data: {document_data}")
        return True
        print("calling AzureAiVisionService perform_ocr")

    async def validate_ocr_response(self, document_data: dict) -> bool:
        return True