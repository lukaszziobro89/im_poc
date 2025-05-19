from abc import ABC, abstractmethod


class RequestStoreService(ABC):
    """Interface for document classification services."""

    def __init__(self):
        pass

    @abstractmethod
    async def put(self, request_id: str) -> dict:
        """Classify the document and return classification results."""
        pass

    @abstractmethod
    async def get(self, request_id: str) -> dict:
        pass

    @abstractmethod
    async def update(self, request_id: str, status:str) -> dict:
        pass

    @abstractmethod
    async def upsert(self, request_id: str) -> dict:
        pass

