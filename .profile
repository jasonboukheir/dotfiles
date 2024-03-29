# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
optional_paths=(
    "$HOME/.bin"
    "$HOME/.local/bin"
    "$HOME/.dotnet/tools"
)

for optional_path in ${optional_paths}
do
    if [ -d "$optional_path" ]
    then
        export PATH="$optional_path:$PATH"
    fi
done

# set vim as default git editor
export GIT_EDITOR=nvim

# fix terminal in tilix
if ! [ -z ${TILIX_ID+x} ]; then
    source /etc/profile.d/vte.csh
fi

# Settings for pipenv
export PIPENV_VENV_IN_PROJECT=1

# Set linuxbrew on path
if [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ] ; then
  eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
fi
. "$HOME/.cargo/env"
