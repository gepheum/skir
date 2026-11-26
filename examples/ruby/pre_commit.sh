#!/bin/bash

set -e

npx skir format
npx skir gen
bundle exec srb tc
bundle exec ruby snippets.rb
