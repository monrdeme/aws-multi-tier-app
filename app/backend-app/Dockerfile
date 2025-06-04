# app/backend-app/Dockerfile

FROM python:3.9.18-slim-bullseye as builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "app.py"]