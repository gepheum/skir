#!/bin/bash

set -e

npm i
npm run lint:fix
npm run lint
npm run format
npm run build
npm run test
