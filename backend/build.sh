#!/bin/bash

# Install Nim if not installed
if ! [ -x "$(command -v nim)" ]; then
  curl https://nim-lang.org/choosenim/init.sh -sSf | sh
  export PATH=$HOME/.nimble/bin:$PATH
fi

# Build the Nim Lambda function
nim c -d:release --threads:on --out:handler handler.nim
zip lambda.zip handler
