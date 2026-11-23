FROM python:3.13.18-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# Le code est monté en volume par compose.yaml : une modification ne demande pas de reconstruire l'image.
COPY . .
