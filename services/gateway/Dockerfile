# Platform gateway image
#
# Talking points:
#   - Same slim Python pattern as team services for consistency.
#   - Build for EKS: docker build --platform linux/amd64 ...
#   - Listens on 0.0.0.0 so the ClusterIP Service can reach uvicorn.

FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
