FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 mlflow

# Install Python dependencies
RUN pip install mlflow==2.8.1 psycopg2-binary boto3

# Switch to non-root user
USER mlflow

# Expose port
EXPOSE 5000

# Default command
CMD ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000"]
