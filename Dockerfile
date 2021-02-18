FROM stoplight/prism

RUN apk update
RUN apk add curl
COPY docs docs