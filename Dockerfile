# EcoWatch — production image (API + admin portal + Flutter web)
# Build context: repository root

# ---- Stage 1: Flutter web ----
FROM ghcr.io/cirruslabs/flutter:stable AS flutter
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
COPY analysis_options.yaml ./
COPY lib ./lib
COPY assets ./assets
COPY web ./web
# Optional project files (ignore if absent — Docker COPY fails on missing paths, so keep only required)
RUN flutter config --enable-web \
  && flutter pub get \
  && flutter build web --release

# ---- Stage 2: Node API ----
FROM node:20-bookworm-slim
WORKDIR /app

COPY backend/package.json backend/package-lock.json ./backend/
RUN cd backend && npm ci --omit=dev

COPY backend ./backend
COPY --from=flutter /src/build/web ./build/web

WORKDIR /app/backend
ENV NODE_ENV=production
EXPOSE 3000

# Migrate schema on boot, then serve API + /admin + Flutter web
CMD ["sh", "-c", "node src/db/migrate.js && node src/index.js"]
