"""
Metrics tracking utility for dissertation time metrics collection.

This module provides timing decorators and logging functions to track
API response times, blockchain transaction times, and database query times
for dissertation Section 4.4 (Test Results and Measures) and Section 6.1
(Findings and Numerical Explanations).
"""

import time
import logging
import functools
import asyncio
from typing import Dict, Any, Optional
import json
import os
from datetime import datetime
from pathlib import Path


# Configure metrics logger
metrics_logger = logging.getLogger("metrics")
metrics_logger.setLevel(logging.INFO)

# Create console handler for metrics
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
formatter = logging.Formatter('[METRICS] %(asctime)s - %(message)s')
console_handler.setFormatter(formatter)
metrics_logger.addHandler(console_handler)


class MetricsTracker:
    """
    Metrics tracking class for dissertation data collection.

    Tracks timing metrics and stores them for analysis. Supports both
    in-memory storage for testing and file-based storage for production.
    """

    def __init__(self, storage_file: Optional[str] = None):
        """
        Initialize metrics tracker.

        Args:
            storage_file: Optional file path to store metrics (JSON format)
        """
        if storage_file:
            self.storage_file = storage_file
        else:
            # Resolve path robustly: check env var first, then use relative path from this file
            env_path = os.getenv('DISSERTATION_METRICS_FILE')
            if env_path:
                self.storage_file = env_path
            else:
                # For containerized environments, use a path within the app directory
                if os.path.exists('/app'):
                    self.storage_file = '/app/metrics/dissertation_metrics.json'
                else:
                    # Path(__file__).resolve().parents[2] gives us the project root
                    self.storage_file = str(Path(__file__).resolve().parents[2] / 'metrics' / 'dissertation_metrics.json')

        self._metrics: Dict[str, list] = {}

        # Ensure metrics directory exists
        os.makedirs(os.path.dirname(self.storage_file), exist_ok=True)

        # Load existing metrics if file exists
        self._load_metrics()

    def start_timer(self) -> float:
        """
        Start a timer for performance measurement.

        Returns:
            float: Start timestamp
        """
        return time.time()

    def end_timer(self, start_time: float) -> float:
        """
        End timer and calculate elapsed time.

        Args:
            start_time: Start timestamp from start_timer()

        Returns:
            float: Elapsed time in seconds
        """
        return time.time() - start_time

    def log_metric(
        self,
        operation_name: str,
        elapsed_time: float,
        additional_data: Optional[Dict[str, Any]] = None
    ) -> None:
        """
        Log a metric measurement with optional additional data.

        Args:
            operation_name: Name of the operation being measured
            elapsed_time: Time elapsed in seconds
            additional_data: Optional dictionary of additional metric data
        """
        timestamp = datetime.utcnow().isoformat()

        metric_entry = {
            "timestamp": timestamp,
            "operation": operation_name,
            "elapsed_time_seconds": elapsed_time,
            "additional_data": additional_data or {}
        }

        # Log to console
        metrics_logger.info(
            f"{operation_name} - time: {elapsed_time:.3f}s - data: {additional_data or {}}"
        )

        # Store in memory
        if operation_name not in self._metrics:
            self._metrics[operation_name] = []
        self._metrics[operation_name].append(metric_entry)

        # Save to file
        self._save_metrics()

    def get_metrics_summary(self, operation_name: Optional[str] = None) -> Dict[str, Any]:
        """
        Get summary statistics for metrics.

        Args:
            operation_name: Optional operation name to filter by

        Returns:
            Dict containing metric summaries
        """
        operations = [operation_name] if operation_name else list(self._metrics.keys())

        summary = {}
        for op in operations:
            if op in self._metrics:
                times = [m["elapsed_time_seconds"] for m in self._metrics[op]]
                summary[op] = {
                    "count": len(times),
                    "total_time": sum(times),
                    "avg_time": sum(times) / len(times) if times else 0,
                    "min_time": min(times) if times else 0,
                    "max_time": max(times) if times else 0
                }

        return summary

    def _load_metrics(self) -> None:
        """Load metrics from storage file."""
        try:
            if os.path.exists(self.storage_file):
                with open(self.storage_file, 'r') as f:
                    self._metrics = json.load(f)
        except Exception as e:
            metrics_logger.warning(f"Failed to load metrics from {self.storage_file}: {e}")
            self._metrics = {}

    def _save_metrics(self) -> None:
        """Save metrics to storage file."""
        try:
            with open(self.storage_file, 'w') as f:
                json.dump(self._metrics, f, indent=2)
        except Exception as e:
            metrics_logger.error(f"Failed to save metrics to {self.storage_file}: {e}")


# Global metrics tracker instance
metrics_tracker = MetricsTracker()


def track_time(operation_name: str, additional_data_func=None):
    """
    Decorator to automatically track execution time of functions (sync and async).

    Args:
        operation_name: Name for the operation
        additional_data_func: Optional function to generate additional data

    Returns:
        Decorated function

    Usage:
        @track_time("database_query")
        def my_function():
            # Function code here
            pass

        @track_time("api_call")
        async def my_async_function():
            # Async function code here
            pass
    """
    def decorator(func):
        @functools.wraps(func)
        def sync_wrapper(*args, **kwargs):
            start_time = metrics_tracker.start_timer()

            try:
                result = func(*args, **kwargs)
                elapsed_time = metrics_tracker.end_timer(start_time)

                # Generate additional data if function provided
                additional_data = None
                if additional_data_func:
                    try:
                        additional_data = additional_data_func(*args, **kwargs)
                    except Exception:
                        additional_data = None

                # Log the metric
                metrics_tracker.log_metric(operation_name, elapsed_time, additional_data)

                return result

            except Exception as e:
                elapsed_time = metrics_tracker.end_timer(start_time)

                # Log error metrics
                error_data = {"error": str(e), "error_type": type(e).__name__}
                metrics_tracker.log_metric(f"{operation_name}_error", elapsed_time, error_data)

                raise

        @functools.wraps(func)
        async def async_wrapper(*args, **kwargs):
            start_time = metrics_tracker.start_timer()

            try:
                result = await func(*args, **kwargs)
                elapsed_time = metrics_tracker.end_timer(start_time)

                # Generate additional data if function provided
                additional_data = None
                if additional_data_func:
                    try:
                        additional_data = additional_data_func(*args, **kwargs)
                    except Exception:
                        additional_data = None

                # Log the metric
                metrics_tracker.log_metric(operation_name, elapsed_time, additional_data)

                return result

            except Exception as e:
                elapsed_time = metrics_tracker.end_timer(start_time)

                # Log error metrics
                error_data = {"error": str(e), "error_type": type(e).__name__}
                metrics_tracker.log_metric(f"{operation_name}_error", elapsed_time, error_data)

                raise

        # Return appropriate wrapper based on whether function is async
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        else:
            return sync_wrapper
    return decorator
