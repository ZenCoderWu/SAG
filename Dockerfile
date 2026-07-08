# ============================================================
# Stage 1: Build API (TypeScript) + Web (Vite/React)
# ============================================================
FROM node:20-slim AS builder

WORKDIR /app

# Install dependencies (all, including devDependencies for build)
COPY package.json package-lock.json ./
RUN npm ci

# Copy source code
COPY tsconfig.json tsconfig.build.json ./
COPY vite.config.ts postcss.config.js tailwind.config.js ./
COPY src/ ./src/
COPY web/ ./web/
COPY scripts/ ./scripts/

# Build API → dist/
# Build Web → web/dist/
RUN npm run build

# ============================================================
# Stage 2: Production image
# ============================================================
FROM node:20-slim AS production

# Install dumb-init for proper signal handling
RUN apt-get update && \
    apt-get install -y --no-install-recommends dumb-init && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r sag && useradd -r -g sag -G sag sag

WORKDIR /app

# Copy package files and install production dependencies
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Copy compiled API from builder
COPY --from=builder /app/dist ./dist

# Copy migrations (needed by dist/src/db/migrate.js which resolves ../.. → dist/)
COPY migrations/ ./dist/migrations/

# Copy compiled Web UI from builder (server.ts serves from <cwd>/web/dist/)
COPY --from=builder /app/web/dist ./web/dist

# Copy entrypoint script
COPY docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh

# Switch to non-root user
USER sag

# Expose ports
# 4173 - HTTP API + Web UI
# 4174 - MCP HTTP transport
EXPOSE 4173 4174

# Health check
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "fetch('http://localhost:4173/health').then(r => r.ok ? process.exit(0) : process.exit(1)).catch(() => process.exit(1))"

# Use dumb-init as PID 1 for proper signal forwarding
ENTRYPOINT ["dumb-init", "--"]
CMD ["./docker-entrypoint.sh"]
