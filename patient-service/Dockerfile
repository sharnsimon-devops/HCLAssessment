FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev

FROM node:20-alpine
RUN addgroup -S -g 10001 appgroup && adduser -S -u 10001 -G appgroup appuser
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY package*.json ./
COPY src ./src
USER appuser
EXPOSE 3000
CMD ["node", "src/index.js"]
