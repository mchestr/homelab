#!/usr/bin/env bash
source ../secrets/.secrets
docker stack deploy base --compose-file base-stack.yaml