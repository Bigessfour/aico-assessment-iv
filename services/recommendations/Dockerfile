# Recommendations service image
#
# Talking points:
#   - Slim Python base keeps the image small for faster pulls on EKS.
#   - We install deps first, then copy app code — Docker layer cache
#     skips reinstall when only app.py changes.
#   - Listen on 0.0.0.0 so the container accepts traffic from the Service
#     (127.0.0.1 would only accept in-pod curls).
#   - Build for EKS with: docker build --platform linux/amd64 ...
#     (Apple Silicon defaults to arm64; EKS nodes are amd64.)

FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
