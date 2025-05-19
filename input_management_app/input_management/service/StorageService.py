from abc import ABC, abstractmethod


class StorageService(ABC):
    def __init__(self):
        pass

    @abstractmethod
    async def put_file(self) -> dict:
        pass

    @abstractmethod
    async def get_file(self) -> dict:
        pass

    @abstractmethod
    async def list_files(self) -> dict:
        pass



