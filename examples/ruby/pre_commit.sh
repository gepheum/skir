#!/bin/bash

set -e

npx skir format
npx skir gen
bundle exec srb tc "$(bundle info --path skir-client)/lib"
bundle exec ruby snippets.rb
