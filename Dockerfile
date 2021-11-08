FROM stoplight/prism:4.5.0

RUN apk update
RUN apk add curl
COPY docs docs