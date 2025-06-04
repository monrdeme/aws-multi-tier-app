# app/frontend-app/Dockerfile

# Use a specific Python base image for consistency and security
# Alpine is lightweight, but consider a debian-slim for better compatibility with some libraries if issues arise
FROM python:3.9.18-slim-bullseye as builder

# Set working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose the port your Flask app runs on
EXPOSE 8000

# Run the Flask app
CMD [ "python", "app.py" ]