from temp.InputManagementWorkflow import InputManagementWorkflow

workflow = InputManagementWorkflow(
    extraction_service=extraction_service,
    classification_service=classification_service,
    storage_service=storage_service,
    ocr_service=ocr_service,
    request_store_service=request_store_service,
    logger=logger
)

# Create your app
app = InputManagementApp(
    # ... your existing parameters
)

# Register the workflow router
workflow_router = create_workflow_router(workflow=workflow, prefix=app.api_prefix)
app.include_router(workflow_router)
# # input_management/app.py
# import uuid
# from typing import List, Optional, Callable
#
# from fastapi import FastAPI, Request, Response
# from fastapi.routing import APIRouter
# from fastapi.middleware.cors import CORSMiddleware
#
# from .api.classification import create_classification_router
# from .api.extensions import register_extension_routers
# from .classification import ClassificationFlow, DefaultClassificationFlow
# from .common.health import create_health_router
# from .errors.handlers import register_exception_handlers
#
#
# class InputManagementApp:
#     """Main application class for input management."""
#
#     def __init__(
#             self,
#             title: str = "Input Management API",
#             description: str = "API for managing and classifying inputs",
#             version: str = "0.1.0",
#             classification_flow: Optional[ClassificationFlow] = None,
#             api_prefix: str = "/api",
#             enable_common_routes: bool = True,
#             enable_cors: bool = True,
#             enable_docs: bool = True,
#             extension_routers: Optional[List[APIRouter]] = None,
#     ):
#         # Create FastAPI application
#         self.app = FastAPI(
#             title=title,
#             description=description,
#             version=version,
#             docs_url="/docs" if enable_docs else None,
#             redoc_url="/redoc" if enable_docs else None,
#         )
#
#         # Set application version
#         self.version = version
#
#         # Set API prefix
#         self.api_prefix = api_prefix
#
#         # Set up classification flow
#         self.classification_flow = classification_flow or DefaultClassificationFlow()
#
#         # Register error handlers
#         register_exception_handlers(self.app)
#
#         # Register middleware
#         self._register_middleware(enable_cors)
#
#         # Register routes
#         if enable_common_routes:
#             self._register_common_routes()
#
#         # Register classification routes
#         self._register_classification_routes()
#
#         # Register extension routers
#         if extension_routers:
#             register_extension_routers(self.app, extension_routers)
#
#     def _register_middleware(self, enable_cors: bool) -> None:
#         """Register middleware."""
#
#         # Add request ID middleware
#         @self.app.middleware("http")
#         async def add_request_id(request: Request, call_next: Callable) -> Response:
#             """Add request ID to request state and response headers."""
#             request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
#             request.state.request_id = request_id
#             response = await call_next(request)
#             response.headers["X-Request-ID"] = request_id
#             return response
#
#         # Add CORS middleware if enabled
#         if enable_cors:
#             self.app.add_middleware(
#                 CORSMiddleware,
#                 allow_origins=["*"],
#                 allow_credentials=True,
#                 allow_methods=["*"],
#                 allow_headers=["*"],
#             )
#
#     def _register_common_routes(self) -> None:
#         """Register common routes."""
#         health_router = create_health_router(
#             app_version=self.version,
#             prefix=self.api_prefix
#         )
#         self.app.include_router(health_router)
#
#     def _register_classification_routes(self) -> None:
#         """Register classification routes."""
#         classification_router = create_classification_router(
#             classification_flow=self.classification_flow,
#             prefix=self.api_prefix
#         )
#         self.app.include_router(classification_router)
#
#     def set_classification_flow(self, classification_flow: ClassificationFlow) -> None:
#         """Set classification flow for the application."""
#         self.classification_flow = classification_flow
#
#     def include_router(self, router: APIRouter) -> None:
#         """Include additional router in the application."""
#         self.app.include_router(router)
#
#     def get_app(self) -> FastAPI:
#         """Get FastAPI application instance."""
#         return self.app