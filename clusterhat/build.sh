#!/bin/bash

docker build -t builder .
docker run --rm -it -v "$(pwd):/data" --workdir "/data" builder make