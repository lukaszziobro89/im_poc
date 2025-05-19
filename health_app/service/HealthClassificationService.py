from input_management_app.input_management.service.ClassificationService import ClassificationService
from input_management_app.input_management.service.RequestStoreService import RequestStoreService


class HealthClassificationService(ClassificationService):
    async def put(self, request_id: str) -> dict:
        print(f"HealthClassificationService: put called with request_id: {request_id}")
        return {
            "request_id": request_id,
            "status": "created",
        }

    async def get(self, request_id: str) -> dict:
        print(f"HealthClassificationService: get called with request_id: {request_id}")
        return {
            "request_id": request_id,
            "status": "completed",
        }