#!/bin/bash

#Debian系の場合

#Neovimの設定
sudo apt -y install neovim
cd ~/.config
mkdir nvim
cd nvim
mv ~/zshrc/init.vim ~/.config/nvim/
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

#tmuxの設定
sudo apt -y install tmux
mv ~/zshrc/tmux.conf ~/.tmux.conf 

#shellの設定(zshの場合)
sudo apt -y install zsh
mv ~/zshrc/zshrc ~/.zshrc

#KVMの設定
sudo apt -y install qemu-kvm
sudo apt -y install virt-manager

#Screeenfetchのインストール
sudo apt -y install screenfetch

#redshiftの設定
sudo apt -y install redshift-gtk
mv ~/zshrc/redshift.conf ~/.config/redshift.conf
