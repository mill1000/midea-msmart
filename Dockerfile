# Build step
FROM python:3.11-alpine as build
RUN apk add --update git
RUN pip install build
WORKDIR /msmart-build
COPY . .
RUN python -m build

# Production step
# Using base alpine package so we can utilize pycryptodome in package repo
FROM alpine:3.18
RUN apk add --update python3 py3-pip py3-pycryptodome
COPY --from=build /msmart-build/dist/msmart_ng-*.whl /tmp
RUN pip install /tmp/msmart_ng-*.whl
ENTRYPOINT ["/usr/bin/msmart-ng"]
