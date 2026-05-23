FROM swift:6.2-jammy AS swift-build
WORKDIR /src
COPY Package.swift Package.resolved ./
COPY Sources ./Sources
COPY Tests ./Tests
RUN swift build -c release

FROM mcr.microsoft.com/playwright:v1.60.0-noble AS runtime
LABEL org.opencontainers.image.source="https://github.com/gitci-labs/screens"
LABEL org.opencontainers.image.description="GitCI Screens CLI and Playwright renderer"
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  git \
  zip \
  && rm -rf /var/lib/apt/lists/*

COPY --from=swift-build /src/.build/release/gitci-screens /usr/local/bin/gitci-screens

WORKDIR /opt/gitci-screens/js
COPY js/package.json js/pnpm-workspace.yaml js/pnpm-lock.yaml js/tsconfig.base.json ./
COPY js/packages ./packages
COPY js/apps ./apps
RUN corepack enable && pnpm install --frozen-lockfile && pnpm build && pnpm --filter @gitci/screens-renderer-node exec playwright install chromium

WORKDIR /opt/gitci-screens
COPY templates ./templates
COPY schemas ./schemas
ENV GITCI_SCREENS_JS_WORKSPACE=/opt/gitci-screens/js
ENV GITCI_SCREENS_TEMPLATES_ROOT=/opt/gitci-screens/templates/gitci/screens

WORKDIR /workspace
ENTRYPOINT ["gitci-screens"]
