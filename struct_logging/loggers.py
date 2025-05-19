import json
import logging
import datetime
import uuid
from typing import Optional, Dict, Any


class BaseJSONLogger(logging.Logger):
    """Base logger class that formats logs as JSON."""

    def __init__(self, name: str, level: int = logging.INFO):
        super().__init__(name, level)
        self._setup_handler()

    def _setup_handler(self):
        """Set up a handler that outputs JSON to standard output."""
        handler = logging.StreamHandler()
        handler.setFormatter(JSONFormatter())
        self.addHandler(handler)

    def _get_base_log_data(self) -> Dict[str, Any]:
        """Get base log data that is common to all loggers."""
        return {
            "datetime": datetime.datetime.now().isoformat(),
            "level": logging.getLevelName(self.level),
        }


class UnifiedLogger(BaseJSONLogger):
    """Unified logger for both domain and audit events."""

    def __init__(self, name: str = "unified", level: int = logging.INFO):
        super().__init__(name, level)
        self.request_id = None

    def set_request_id(self, request_id: Optional[str] = None):
        """Set the request ID for the current context."""
        self.request_id = request_id or str(uuid.uuid4())
        return self.request_id

    def info(self, event: str, **kwargs):
        """Log a domain event."""
        log_data = self._get_base_log_data()
        log_data.update({
            "log_type": "domain",
            "event": event,
            "event_id": str(uuid.uuid4()),
            "request_id": self.request_id or str(uuid.uuid4()),
        })
        log_data.update(kwargs)
        super().info(json.dumps(log_data))

    def audit(self, event: str, http_method: str, path: str, base_url: str,
              status_code: int, client: Optional[str] = None,
              client_ip_address: Optional[str] = None, **kwargs):
        """Log an audit event."""
        log_data = self._get_base_log_data()
        log_data.update({
            "log_type": "audit",
            "event": event,
            "event_id": str(uuid.uuid4()),
            "request_id": self.request_id or str(uuid.uuid4()),
            "http_method": http_method,
            "path": path,
            "base_url": base_url,
            "status_code": status_code,
            "client": client or "unknown",
            "client_ip_address": client_ip_address or "0.0.0.0",
        })
        log_data.update(kwargs)
        super().info(json.dumps(log_data))


class JSONFormatter(logging.Formatter):
    """Formatter that ensures logs are in valid JSON format."""

    def format(self, record):
        """Format the log record as JSON if it isn't already."""
        message = record.getMessage()

        # If the message is already JSON, return it as is
        try:
            json.loads(message)
            return message
        except (json.JSONDecodeError, TypeError):
            # If not JSON, convert it to a simple JSON message
            log_data = {
                "message": message,
                "level": record.levelname,
                "logger": record.name,
            }
            return json.dumps(log_data)