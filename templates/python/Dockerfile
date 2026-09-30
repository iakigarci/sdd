# Services only: /project-init deletes this for CLIs and libraries.
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS build
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=0
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-install-project --no-dev
COPY . .
RUN uv sync --locked --no-dev

FROM python:3.13-slim-bookworm
RUN useradd --system --uid 10001 app
COPY --from=build --chown=app:app /app /app
ENV PATH="/app/.venv/bin:$PATH"
USER app
WORKDIR /app
ENTRYPOINT ["{{ENTRYPOINT}}"]
