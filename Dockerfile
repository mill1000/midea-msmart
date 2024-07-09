# Build step
FROM python:3.12-alpine AS build
RUN apk add --update git
RUN pip install build
WORKDIR /msmart-build
COPY . .
RUN python -m build

# Production step
# Using base alpine package so we can utilize pycryptodome in package repo
FROM alpine:3.20
RUN apk add --update python3 pipx py3-pycryptodome
COPY --from=build /msmart-build/dist/msmart_ng-*.whl /tmp
RUN PIPX_BIN_DIR=/usr/bin pipx install --system-site-packages /tmp/msmart_ng-*.whl
ENTRYPOINT ["/usr/bin/msmart-ng"]
