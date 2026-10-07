FROM python:3.12-slim

# Run as an unprivileged user, not root
RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

USER appuser

EXPOSE 5001

CMD ["python", "app/app.py"]
