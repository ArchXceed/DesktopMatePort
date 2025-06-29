pid=$(hyprctl -j clients | jq -r '.[] | select(.title == "shell - Wine Desktop") | .pid')
current_workspace=$(hyprctl activeworkspace -j | jq '.id')
hyprctl dispatch movetoworkspacesilent $current_workspace,pid:$pid
