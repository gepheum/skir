#!/bin/bash

set -e

npm i
npm run lint:fix
npm run lint
npm run format
npm run build
npx esbuild src/get_dependencies_flow.ts --bundle --platform=browser --format=esm --outfile=/tmp/get_dependencies_flow.browser-check.js
npm run test
