pid=$(hyprctl -j clients | jq -r '.[] | select(.title == "shell - Wine Desktop") | .pid')
hyprctl dispatch movetoworkspacesilent 88,pid:$pid
