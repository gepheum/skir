#!/bin/bash

set -e

npm i
npm run format
npm run build
npm run test
npm run snippets
