#!/bin/bash

set -e

npx skir format
npx skir gen
gofmt -w $(find . -name '*.go' -not -path '*/skirout/*' -not -path '*/.git/*')
go build ./...
go run .
