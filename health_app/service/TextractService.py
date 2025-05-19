from input_management_app.input_management.service.OcrService import OcrService


class TextractService(OcrService):
    async def perform_ocr(self, document_data: dict) -> dict:
        print(f"TextractService: perform_ocr called with document_data: {document_data}")
        return {
            "text": "Sample OCR text",
            "language": "en"
        }