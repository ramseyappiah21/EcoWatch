# EcoWatch API + admin portal (Render-friendly)
# Flutter web is optional: build locally and copy into backend/public/web if needed.
# Context: repository root

FROM node:20-bookworm-slim

WORKDIR /app

COPY backend/package.json backend/package-lock.json ./
RUN npm ci --omit=dev

COPY backend ./

ENV NODE_ENV=production
ENV PORT=3000
EXPOSE 3000

# Migrate always. Seed demo accounts when SEED_ON_BOOT=true (no paid Render Shell needed).
CMD ["sh", "-c", "node src/db/migrate.js && if [ \"$SEED_ON_BOOT\" = \"true\" ]; then node src/db/seed.js; fi && node src/index.js"]
