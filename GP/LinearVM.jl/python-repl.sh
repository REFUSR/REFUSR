#! /usr/bin/env bash

pip3 install -r requirements.txt

python-jl -m IPython --no-confirm-exit --no-banner --quick \
  --InteractiveShellApp.extensions="autoreload" \
  --InteractiveShellApp.exec_lines="%autoreload 2" \
  --InteractiveShellApp.exec_lines="from linearvmpy import *"
