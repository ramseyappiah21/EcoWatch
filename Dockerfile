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

# Migrate schema, then serve API + /admin (+ citizen web if present under public/web)
CMD ["sh", "-c", "node src/db/migrate.js && node src/index.js"]
