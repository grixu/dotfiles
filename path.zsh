# Load dotfiles binaries
export PATH="$DOTFILES/bin:$PATH"

# Load Composer tools
export PATH="$HOME/.composer/vendor/bin:$PATH"

# Load Rustup
export PATH="$HOME/.cargo/bin:$PATH"

# Load Node global installed binaries
export PATH="$HOME/.node/bin:$PATH"

# Use project specific binaries before global ones
export PATH="node_modules/.bin:vendor/bin:$PATH"

# Homebrew (both)
export PATH="/usr/local/homebrew/bin:/usr/local/homebrew/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# Make sure coreutils are loaded before system commands
# I've disabled this for now because I only use "ls" which is
# referenced in my aliases.zsh file directly.
#export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"

# PHP 8.1
#export PATH="/usr/local/homebrew/opt/php@8.1/bin:$PATH"
#export PATH="/usr/local/homebrew/opt/php@8.1/sbin:$PATH"
