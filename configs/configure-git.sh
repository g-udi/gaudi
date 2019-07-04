# Update global git config
git lfs install
# Your place for hosting Git repos. I use this for private repos.
export GIT_HOSTING='git@github.com'

prompt "Set git defaults"
for config in "${git_configs[@]}"
do
  git config --global ${config}
done