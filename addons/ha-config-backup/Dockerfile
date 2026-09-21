ARG BUILD_FROM=alpine:3.20
FROM ${BUILD_FROM}

RUN apk add --no-cache git openssh-client jq bash

# backup.sh = one cycle; run.sh = scheduler loop (own process, no external cron)
COPY run.sh backup.sh /
RUN chmod a+x /run.sh /backup.sh

WORKDIR /
CMD ["/run.sh"]
