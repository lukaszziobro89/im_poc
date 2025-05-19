from input_management_app.input_management.service.RequestStoreService import RequestStoreService


class DatabricksVolumeService(RequestStoreService):
    async def put(self, request_id: str) -> dict:
        print(f"DatabricsVolumeService: put called with request_id: {request_id}")
        return {}

    async def get(self, request_id: str) -> dict:
        print(f"DatabricsVolumeService: put called with request_id: {request_id}")
        return {
            "request_id": request_id,
            "status": "completed",
        }

    async def update(self, request_id: str, status: str) -> dict:
        print(f"DatabricsVolumeService: put called with request_id: {request_id}")
        return {
            "request_id": request_id,
        }

    async def upsert(self, request_id: str) -> dict:
        print(f"DatabricsVolumeService: put called with request_id: {request_id}")
        return {
            "request_id": request_id,
        }
