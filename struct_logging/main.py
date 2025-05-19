import logging

import loggers
import datetime
import uuid
from typing import Optional, List

import uvicorn
from fastapi import FastAPI, Request, Depends, HTTPException, status
from starlette.middleware.base import BaseHTTPMiddleware
from pydantic import BaseModel
from loggers import DomainLogger,AuditLogger,BaseJSONLogger
# ---- FastAPI Application ----

# Initialize loggers
domain_logger = DomainLogger()
audit_logger = AuditLogger()

# Register loggers with Python's logging system
logging.setLoggerClass(BaseJSONLogger)
logging.getLogger("domain").setLevel(logging.INFO)
logging.getLogger("audit").setLevel(logging.INFO)

app = FastAPI(title="Sample API with Custom Logging")


# Define Pydantic models for API
class User(BaseModel):
    username: str
    email: str
    full_name: Optional[str] = None


class Item(BaseModel):
    name: str
    description: Optional[str] = None
    price: float
    tax: Optional[float] = None


# Storage for our example (in a real app, this would be a database)
users_db = {}
items_db = {}


# Middleware for logging
class AuditLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Generate request_id if not present
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))

        # Set request ID for domain logger
        domain_logger.set_request_id(request_id)

        # Add request_id to request state
        request.state.request_id = request_id

        # Process the request
        start_time = datetime.datetime.now()

        try:
            response = await call_next(request)

            # Calculate processing time
            process_time = (datetime.datetime.now() - start_time).total_seconds() * 1000

            # Log the request with audit logger
            audit_logger.log_request(
                http_method=request.method,
                path=request.url.path,
                base_url=str(request.base_url).rstrip('/'),
                status_code=response.status_code,
                client=request.headers.get("User-Agent", "unknown"),
                client_ip_address=request.client.host if request.client else "0.0.0.0",
                request_id=request_id,
                process_time_ms=round(process_time, 2)
            )

            # Add request_id to response headers
            response.headers["X-Request-ID"] = request_id
            return response

        except Exception as e:
            # Log exception with audit logger
            process_time = (datetime.datetime.now() - start_time).total_seconds() * 1000

            audit_logger.log_request(
                http_method=request.method,
                path=request.url.path,
                base_url=str(request.base_url).rstrip('/'),
                status_code=500,
                client=request.headers.get("User-Agent", "unknown"),
                client_ip_address=request.client.host if request.client else "0.0.0.0",
                request_id=request_id,
                process_time_ms=round(process_time, 2),
                error=str(e)
            )

            # Re-raise the exception
            raise


# Add middleware to FastAPI app
app.add_middleware(AuditLoggingMiddleware)


# Dependency to get request_id
async def get_request_id(request: Request) -> str:
    return request.state.request_id


# ----- API Endpoints -----

@app.get("/")
async def root():
    return {"message": "Welcome to our API with custom logging"}


@app.post("/users/", response_model=User, status_code=status.HTTP_201_CREATED)
async def create_user(user: User, request_id: str = Depends(get_request_id)):
    if user.username in users_db:
        domain_logger.log_event(
            event="user_creation_failed",
            reason="username_exists",
            username=user.username
        )
        raise HTTPException(status_code=400, detail="Username already registered")

    users_db[user.username] = user.dict()

    # Domain logging for user creation
    domain_logger.log_event(
        event="user_created",
        username=user.username,
        email=user.email
    )

    return user


@app.get("/users/{username}", response_model=User)
async def get_user(username: str, request_id: str = Depends(get_request_id)):
    if username not in users_db:
        domain_logger.log_event(
            event="user_retrieval_failed",
            reason="user_not_found",
            username=username
        )
        raise HTTPException(status_code=404, detail="User not found")

    domain_logger.log_event(
        event="user_retrieved",
        username=username
    )

    return users_db[username]


@app.post("/items/", response_model=Item)
async def create_item(item: Item, request_id: str = Depends(get_request_id)):
    item_id = str(uuid.uuid4())
    items_db[item_id] = item.dict()

    # Domain logging for item creation
    domain_logger.log_event(
        event="item_created",
        item_id=item_id,
        item_name=item.name,
        price=item.price
    )

    return item


@app.get("/items/", response_model=List[Item])
async def list_items(request_id: str = Depends(get_request_id)):
    # Domain logging for items listing
    domain_logger.log_event(
        event="items_listed",
        item_count=len(items_db)
    )

    return list(items_db.values())


@app.get("/error-test/")
async def trigger_error(request_id: str = Depends(get_request_id)):
    domain_logger.log_event(
        event="error_endpoint_called",
        level=logging.WARNING
    )

    # Deliberately raise an exception to test error logging
    raise ValueError("This is a test error to demonstrate error logging")


# Run the application
if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)