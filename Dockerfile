FROM python:3.11-alpine AS builder

WORKDIR /build

# gcc + musl-dev needed to compile uvloop and httptools (uvicorn[standard])
RUN apk add --no-cache gcc musl-dev

COPY requirements.txt .
# ponytail: strip test-only packages — pytest/httpx/fakeredis/PyYAML not needed at runtime
RUN grep -vE "^(#|pytest|httpx|fakeredis|PyYAML)" requirements.txt \
    | pip install --no-cache-dir --prefix=/install -r /dev/stdin


FROM python:3.11-alpine AS runtime

WORKDIR /app

COPY --from=builder /install /usr/local

RUN adduser -D -u 10001 appuser

COPY app ./app
COPY utils ./utils

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health').read()" || exit 1

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
