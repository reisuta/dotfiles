#!/bin/zsh
if [ "$#" -eq 0 ]; then
  tmux split-window -h
  tmux split-window -v
  tmux select-pane -L
  tmux split-window -v
  tmux send-keys "rails s" C-m
  tmux select-pane -R
  tmux send-keys "rails c" C-m
  tmux select-pane -U
  tmux select-pane -L
  tmux send-keys "n" C-m
else
  case $1 in
    1)
      tmux split-window -h
      tmux split-window -v
      tmux select-pane -L
      tmux split-window -v
      tmux send-keys "bin/webpack-dev-server" C-m
      tmux select-pane -R
      tmux send-keys "rails s" C-m
      tmux select-pane -U
      tmux send-keys "ls" C-m
      tmux select-pane -L
      tmux send-keys "n" C-m
      clear
      ;;
    2)
      tmux split-window -h
      tmux split-window -v
      tmux resize-pane -D 15
      tmux select-pane -t 1
      tmux split-window -v
      tmux select-pane -t 1
      clear
      ;;
    py)
      cd ~/Desktop
      tmux split-window -v
      tmux split-window -h
      tmux resize-pane -D 15
      tmux select-pane -t 1
      vi .
      clear
      ;;
    *)
      echo [ERROR] "$1" は設定されていない引数です。
      ;;
  esac
fi
