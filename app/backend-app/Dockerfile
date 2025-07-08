# app/backend-app/Dockerfile

FROM python:3.9.18-slim-bullseye as builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt gunicorn

COPY . .

EXPOSE 5000

# Sets an environment variable inside the container which tells Python where to look for modules when running app
ENV PYTHONPATH /app

# Use Gunicorn to run your Flask application
# 'app:app' means:
# 'app' (first part): refers to your app.py file (the Python module)
# 'app' (second part): refers to the 'app' Flask instance within app.py (app = Flask(__name__))
# -w 4: Starts 4 worker processes. Adjust based on your instance's vCPU count. A t3.micro has 2 vCPUs, so 2-4 workers is a good start.
# -b 0.0.0.0:5000: Binds Gunicorn to all network interfaces on port 5000 (your containerPort).
CMD [ "gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app" ]