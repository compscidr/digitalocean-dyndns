FROM alpine
LABEL org.opencontainers.image.authors="Jason Ernst <ernstjason1@gmail.com>"
RUN apk --no-cache add curl jq bash
COPY dyndns.sh /
USER nobody
ENTRYPOINT exec /dyndns.sh
