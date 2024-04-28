#!/bin/bash

currentPath="$(pwd)"
for action in "daemon" "panel" "frontend"
do
    gnome-terminal -- bash -c "cd $currentPath && npm run $action"
done
