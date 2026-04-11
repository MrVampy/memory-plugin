#!/bin/bash
# Thin wrapper around `memory validate`.
# Exits 0 on clean wiki, non-zero when errors exist. Output lists the errors.
exec memory validate "$@"
