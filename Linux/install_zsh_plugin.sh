
# Powerlevel10k theme for Zsh.
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

# Zsh plugins
git clone --depth=1 git@github.com:zsh-users/zsh-syntax-highlighting.git "${ZSH}/plugins/zsh-syntax-highlighting"
git clone --depth=1 git@github.com:zsh-users/zsh-autosuggestions.git "${ZSH}/plugins/zsh-autosuggestions"
git clone --depth=1 git@github.com:zsh-users/zsh-history-substring-search.git "${ZSH}/plugins/zsh-history-substring-search"

sudo apt install -y fzf
