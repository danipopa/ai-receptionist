FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev dependencies needed for build)
RUN npm ci && npm cache clean --force

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Create non-root user
RUN addgroup -g 1001 -S nuxt && adduser -S nuxt -u 1001
RUN chown -R nuxt:nuxt /app
USER nuxt

# Expose port
EXPOSE 3000

# Environment variables
ENV API_HOST=backend-api
ENV API_PORT=3000
ENV API_BASE_URL=http://backend-api:3000/api/v1
ENV PORT=3000

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

# Start the application
CMD ["node", ".output/server/index.mjs"]