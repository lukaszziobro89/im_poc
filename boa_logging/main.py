import uuid
import datetime
import logging
from typing import Optional, List

import uvicorn
from fastapi import FastAPI, Request, Response, Depends, HTTPException, status
from starlette.middleware.base import BaseHTTPMiddleware
from pydantic import BaseModel

# Import logging configuration from your package
# This assumes common.logging sets up logging configurations
import common.logging

# ---- FastAPI Application ----

# Get loggers using standard logging
domain_logger = logging.getLogger("domain")
audit_logger = logging.getLogger("audit")


domain_logger.setLevel(logging.INFO)
audit_logger.setLevel(logging.INFO)
# Create FastAPI app
app = FastAPI(title="Hello API with Custom Logging")


# Define Pydantic models for API
class Product(BaseModel):
    name: str
    description: Optional[str] = None
    price: float
    in_stock: bool = True


# Sample in-memory database
products_db = {}


# Middleware for audit logging
class AuditLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Generate request_id
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))

        # Store request_id in request state
        request.state.request_id = request_id

        # Process request and measure duration
        start_time = datetime.datetime.now()

        try:
            # Call next middleware or route handler
            response = await call_next(request)

            # Calculate processing time
            process_time = (datetime.datetime.now() - start_time).total_seconds() * 1000

            # Log the HTTP request with audit information
            audit_logger.info(
                f"HTTP Request - Method: {request.method}, Path: {request.url.path}, "
                f"Status: {response.status_code}, Client IP: {request.client.host if request.client else '0.0.0.0'}, "
                f"Process Time: {round(process_time, 2)}ms, Request ID: {request_id}"
            )

            # Add request_id to response headers
            response.headers["X-Request-ID"] = request_id
            return response

        except Exception as e:
            # Log exception
            process_time = (datetime.datetime.now() - start_time).total_seconds() * 1000

            audit_logger.error(
                f"HTTP Request Failed - Method: {request.method}, Path: {request.url.path}, "
                f"Status: 500, Client IP: {request.client.host if request.client else '0.0.0.0'}, "
                f"Process Time: {round(process_time, 2)}ms, Request ID: {request_id}, "
                f"Error: {str(e)}"
            )

            # Re-raise the exception
            raise


# Add middleware to app
app.add_middleware(AuditLoggingMiddleware)  # type: ignore

# Dependency to get request_id
async def get_request_id(request: Request) -> str:
    return request.state.request_id


# Function to create structured log dict
def create_domain_log(event_name, **kwargs):
    log_data = {
        "log_type": "domain",
        "datetime": datetime.datetime.now().isoformat(),
        "event": event_name,
    }
    log_data.update(kwargs)
    return log_data


# ---- API Endpoints ----

@app.get("/")
async def root():
    """Root endpoint that returns a simple welcome message."""
    return {"message": "Hello World! Welcome to our API with custom logging"}


@app.get("/health")
async def health_check(request_id: str = Depends(get_request_id)):
    """Health check endpoint that logs a domain event."""
    domain_logger.info(
        f"Health Check - Status: healthy, Request ID: {request_id}"
    )
    # logging.basicConfig(level=logging.INFO)
    return {"status": "healthy", "request_id": request_id}


@app.post("/products/", response_model=Product, status_code=status.HTTP_201_CREATED)
async def create_product(product: Product, request_id: str = Depends(get_request_id)):
    """Create a new product and log the domain event."""
    product_id = str(uuid.uuid4())
    products_db[product_id] = product.dict()

    # Domain logging for product creation
    log_data = create_domain_log(
        "product_created",
        product_id=product_id,
        product_name=product.name,
        price=product.price,
        request_id=request_id
    )
    domain_logger.info(f"Product Created - {log_data}")

    return product


@app.get("/products/{product_id}", response_model=Product)
async def get_product(product_id: str, request_id: str = Depends(get_request_id)):
    """Get a product by ID and log the domain event."""
    if product_id not in products_db:
        log_data = create_domain_log(
            "product_retrieval_failed",
            reason="product_not_found",
            product_id=product_id,
            request_id=request_id
        )
        domain_logger.warning(f"Product Retrieval Failed - {log_data}")
        raise HTTPException(status_code=404, detail="Product not found")

    log_data = create_domain_log(
        "product_retrieved",
        product_id=product_id,
        request_id=request_id
    )
    domain_logger.info(f"Product Retrieved - {log_data}")

    return products_db[product_id]


@app.get("/products/", response_model=List[Product])
async def list_products(request_id: str = Depends(get_request_id)):
    """List all products and log the domain event."""
    log_data = create_domain_log(
        "products_listed",
        product_count=len(products_db),
        request_id=request_id
    )
    domain_logger.info(f"Products Listed - {log_data}")

    return list(products_db.values())


@app.put("/products/{product_id}", response_model=Product)
async def update_product(product_id: str, product: Product, request_id: str = Depends(get_request_id)):
    """Update a product and log the domain event."""
    if product_id not in products_db:
        log_data = create_domain_log(
            "product_update_failed",
            reason="product_not_found",
            product_id=product_id,
            request_id=request_id
        )
        domain_logger.warning(f"Product Update Failed - {log_data}")
        raise HTTPException(status_code=404, detail="Product not found")

    # Update product
    products_db[product_id] = product.dict()

    log_data = create_domain_log(
        "product_updated",
        product_id=product_id,
        product_name=product.name,
        price=product.price,
        request_id=request_id
    )
    domain_logger.info(f"Product Updated - {log_data}")

    return product


@app.delete("/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_product(product_id: str, request_id: str = Depends(get_request_id)):
    """Delete a product and log the domain event."""
    if product_id not in products_db:
        log_data = create_domain_log(
            "product_deletion_failed",
            reason="product_not_found",
            product_id=product_id,
            request_id=request_id
        )
        domain_logger.warning(f"Product Deletion Failed - {log_data}")
        raise HTTPException(status_code=404, detail="Product not found")

    # Get product details before deletion for logging
    product = products_db[product_id]

    # Delete product
    del products_db[product_id]

    log_data = create_domain_log(
        "product_deleted",
        product_id=product_id,
        product_name=product["name"],
        request_id=request_id
    )
    domain_logger.info(f"Product Deleted - {log_data}")

    return None


@app.get("/error")
async def trigger_error(request_id: str = Depends(get_request_id)):
    """Endpoint that deliberately triggers an error to demonstrate error logging."""
    log_data = create_domain_log(
        "error_endpoint_called",
        request_id=request_id
    )
    domain_logger.warning(f"Error Endpoint Called - {log_data}")

    # Deliberately raise an exception
    raise ValueError("This is a test error to demonstrate error logging")


# Run the application
# if __name__ == "__main__":
    # uvicorn.run("hello:app", host="0.0.0.0", port=8000, reload=True)