#!/usr/bin/env bash

tests_to_run=()

if [ "$#" -gt 0 ]; then
  tests_to_run=("$@")
fi

if [ "${#tests_to_run[@]}" -eq 0 ]; then
  XDG_CONFIG_HOME=$(pwd)/test/tmp \
  XDG_DATA_HOME=$(pwd)/test/tmp \
  nvim --headless \
    -i NONE \
    --noplugin \
    -u "test/minimal_init.lua" \
    -c "PlenaryBustedDirectory test/specs" \
    -c "qa!"
else
  for test_file in "${tests_to_run[@]}"; do
    XDG_CONFIG_HOME=$(pwd)/test/tmp/empty_config \
    XDG_DATA_HOME=$(pwd)/test/tmp/empty_data \
    nvim --headless \
      -i NONE \
      --noplugin \
      -u "test/minimal_init.lua" \
      -c "lua require('plenary.busted').run('$test_file')" \
      -c "qa!"
  done
fi
