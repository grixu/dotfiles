# Shortcuts
alias copyssh="pbcopy < $HOME/.ssh/id_ed25519.pub"
alias reloadshell="source $HOME/.zshrc"
alias flushdns="dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
alias ll="eza -Ahlo --color --group-directories-first"
alias llo="/opt/homebrew/opt/coreutils/libexec/gnubin/ls -AhlFo --color --group-directories-first"
alias phpstorm='open -a /Applications/PhpStorm.app "`pwd`"'
alias shrug="echo '¯\_(ツ)_/¯' | pbcopy"
alias c="clear"

# Directories
alias dotfiles="cd $DOTFILES"
alias library="cd $HOME/Library"
alias as="cd $HOME/archisquad"

# Laravel
alias a="php artisan"
alias fresh="php artisan migrate:fresh --seed"
alias seed="php artisan db:seed"
alias pu='vendor/bin/phpunit'
alias xpu='XDEBUG_MODE=coverage vendor/bin/phpunit'

# PHP
alias cfresh="rm -rf vendor/ composer.lock && composer i"
alias composer="php -d memory_limit=-1 /opt/homebrew/bin/composer"

# JS
alias nfresh="rm -rf node_modules/ package-lock.json && npm install"
alias watch="npm run watch"

# Docker
alias docker-composer="docker compose"

# Git
alias gst="git status"
alias gb="git branch"
alias gl="git log --oneline --decorate --color"
alias amend="git add . && git commit --amend --no-edit"
alias gcn="git commit --no-verify -m"
alias diff="git diff"
alias force="git push --force"
alias nuke="git clean -df && git reset --hard"
alias pop="git stash pop"
alias pull="git pull"
alias push="git push"
alias resolve="git add . && git commit --no-edit"
alias stash="git stash -u"
alias unstage="git restore --staged ."
alias wip="commit wip"

# Redis
alias flush-redis="redis-cli FLUSHALL"

# VSCode
alias code='open -a "/Applications/Visual Studio Code.app" "`pwd`"'
alias code-insiders='open -a "/Applications/Visual Studio Code - Insiders.app" "`pwd`"'

# Better versions of some unix utilities
alias cat='bat'
alias ls='eza'
alias dig='dog'
