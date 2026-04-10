FROM oven/bun:1 AS base
WORKDIR /app

# --- Install dependencies ---
FROM base AS deps
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile --production

# --- Build stage (install all deps for TypeScript checking) ---
FROM base AS build
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile
COPY . .

# --- Production image ---
FROM base AS production
ENV NODE_ENV=production

COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/src ./src
COPY --from=build /app/package.json ./
COPY --from=build /app/tsconfig.json ./

EXPOSE 3000

CMD ["bun", "run", "src/index.ts"]
