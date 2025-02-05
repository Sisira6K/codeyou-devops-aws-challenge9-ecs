FROM node:18-alpine
RUN apk add --no-cache bash
ENV NODE_ENV=production
EXPOSE 6673
RUN addgroup -S spacex && adduser -S -G spacex spacex # FIXME: check this
RUN mkdir -p /app && chown spacex /app
WORKDIR /app
ENTRYPOINT [ "/app/start.sh" ]
COPY --chown=spacex:spacex package.json package-lock.json /app/
RUN npm install --production
COPY --chown=spacex:spacex . .
