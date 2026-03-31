FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt /app/requirements.txt

RUN apt-get update \
  && apt-get install -y --no-install-recommends wget libgomp1 \
  && rm -rf /var/lib/apt/lists/* \
  && pip install --no-cache-dir --upgrade pip \
  && pip install --no-cache-dir -r /app/requirements.txt \
  && pip install --no-cache-dir torch torchaudio --index-url https://download.pytorch.org/whl/cpu

COPY app /app/app

EXPOSE 8085

CMD ["uvicorn", "app.main:create_app", "--factory", "--host", "0.0.0.0", "--port", "8085"]
