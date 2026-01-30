# Small official Python image (pin patch if you want even less drift)
FROM python:3.11-slim

# Predictable Python behavior in containers
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Working directory inside the container
WORKDIR /app

# Install dependencies first (better layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r /app/requirements.txt

# Create a non-root user and group, then own the app directory
RUN groupadd -r app && useradd -r -g app -d /app -s /usr/sbin/nologin app \
    && chown -R app:app /app

# Copy application code
COPY app.py .

# Switch to non-root user (this is the key line for “non-root container”)
USER app

# Document port (doesn't publish by itself)
EXPOSE 8000

# Run the service
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]