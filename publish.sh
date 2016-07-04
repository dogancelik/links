# Set config

git config --global push.default simple
git config --global user.name "CircleCI"
git config --global user.email circleci@users.noreply.github.com

# Clone build repo

rm -rf build
git clone git@github.com:links-js/links-js.github.io.git build

# Build

shopt -s expand_aliases
alias nbin='PATH=$(npm bin):$PATH'
nbin gulp

# Prepare commit message

[[ ! -z "$CIRCLE_BUILD_NUM" ]] && BUILD_SUFFIX=" #$CIRCLE_BUILD_NUM"
COMMIT_HEADER="CircleCI Build$BUILD_SUFFIX"
COMMIT_MSG="$(git log --format=%B -1)"
COMMIT_CONCAT=$(echo -e "$COMMIT_HEADER\n\n$COMMIT_MSG")

echo -e "==============\nCOMMIT MESSAGE\n==============\n$COMMIT_CONCAT"

# Process the commit

cd build
git add -A
git commit -m "$COMMIT_HEADER" -m "$COMMIT_MSG"
git push
