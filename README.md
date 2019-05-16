# dotfiles
Clone this repository:
`$ git clone https://gitlab.com/jasonboukheir/dotfiles.git ~/dotfiles`

Install zsh:
```
$ sudo apt install zsh
$ chsh -s $(which zsh)
```

Install bashdot:
```
$ curl -s https://raw.githubusercontent.com/bashdot/bashdot/master/bashdot > bashdot
$ sudo mv bashdot /usr/local/bin
$ sudo chmod a+x /usr/local/bin/bashdot
```

Then run:
`$ bashdot install dotfiles`

