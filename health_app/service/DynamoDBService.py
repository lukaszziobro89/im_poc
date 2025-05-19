from input_management_app.input_management.service.RequestStoreService import RequestStoreService


class DynamoDbService(RequestStoreService):
    async def put(self, request_id: str) -> dict:
        print(f"DynamoDbService: put called with request_id: {request_id}")
        return {
            "request_id": request_id,
            "status": "created",
        }

    async def get(self, request_id: str) -> dict:
        print(f"DynamoDbService: get called with request_id: {request_id}")
        return {
            "request_id": request_id,
            "status": "completed",
        }

    async def update(self, request_id: str, status: str) -> dict:
        print(f"DynamoDbService: update called with request_id: {request_id}")
        return {
            "request_id": request_id,
            "status": status,
        }