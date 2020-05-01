#!/usr/bin/env bash
# install zsh
sudo apt install zsh -y
chsh -s $(which zsh)

# install bashdot
if [ ! -f /usr/local/bin/bashdot ]; then
	curl -s https://raw.githubusercontent.com/bashdot/bashdot/master/bashdot > bashdot
	sudo mv bashdot /usr/local/bin
	sudo chmod a+x /usr/local/bin/bashdot
fi
