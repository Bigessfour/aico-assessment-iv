# Dashboard image notes:
#   - Multi-stage: Node build → nginx alpine runtime
#   - Must be linux/amd64 for EKS (Apple Silicon hosts: --platform linux/amd64)
#   - No secrets in the image; API calls go through /api proxy at runtime

FROM node:18-alpine AS build

WORKDIR /app

COPY package*.json ./
# Lockfile is committed, so builds are reproducible.
RUN npm ci --silent

COPY . ./
# Bake relative /api so nginx can proxy to the gateway in-cluster
ENV VITE_API_BASE=/api
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
