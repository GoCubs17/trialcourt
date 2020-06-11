#!/bin/bash

set -e

# Include project variables.
. .circleci/scripts/project-${1}.sh

# GIT url of the artifact repo.
ARTIFACT_GIT=ssh://codeserver.dev.${UUID}@codeserver.dev.${UUID}.drush.in:2222/~/repository.git
TIMESTAMP=$(date +'%y-%m-%dT%H:%m:%S')
PANTHEON_ENV=$CIRCLE_BRANCH

git config --global user.email "$GIT_EMAIL"
git config --global user.name "Ch3-P0"

echo "\nClone artifact.\n"
mkdir -p data
cd data
git clone $ARTIFACT_GIT artifact
echo "\nCheckout $CIRCLE_BRANCH\n"
cd artifact
git fetch origin && git checkout $CIRCLE_BRANCH
git pull origin $CIRCLE_BRANCH
echo "\nSync to artifact.\n"
cd ../.. && composer -n artifact-sync
cd data/artifact
git add .
git commit -am "Built assets. $TIMESTAMP"
echo "\n@todo- Work out release taging.\n"

# Tag for master.
if [ $CIRCLE_BRANCH == 'master' ] ; then
  # For drush reset.
  PANTHEON_ENV=live

  # Get latest pantheon_live_ tag.
  git fetch origin --tags
  pantheon_prefix='pantheon_live_'
  pantheon_current=$(git tag -l --sort=v:refname $pantheon_prefix* | tail -1)
  if [ -z $pantheon_current ] ; then
    # No current tag so start with 1.
    pantheon_new=1
  else
    pantheon_id=${pantheon_current#${pantheon_prefix}}
    pantheon_new=$(($pantheon_id+1))
  fi
  echo
  echo "Tagging master branch for production (Live): $pantheon_prefix$pantheon_new"

  git tag -a $pantheon_prefix$pantheon_new -m "Tagging new pantheon live release."
fi

# Disable strict host checking so we can push code and run drush on all envs.
echo -e "Host codeserver.dev.${UUID}.drush.in\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config
echo -e "Host appserver.${PANTHEON_ENV}.${UUID}.drush.in\n\tStrictHostKeyChecking no\n" >> ~/.ssh/config

echo
echo "Pushing $CIRCLE_BRANCH"
git push origin $CIRCLE_BRANCH -f --tags

# Reset env.

# Give pantheon a chance for code to sync first.
# May need to adjust this value.

WAIT=45
echo
echo "Waiting $WAIT seconds for code to sync on host."
sleep $WAIT

echo
echo Clearing Cache for $PANTHEON_ENV
drush @${SITE_CODE}.${PANTHEON_ENV} cr

echo
echo Running Database Updates for $PANTHEON_ENV
drush @${SITE_CODE}.${PANTHEON_ENV} updb -y

echo
echo Importing Config for $PANTHEON_ENV
drush @${SITE_CODE}.${PANTHEON_ENV} cim -y

echo
echo Clearing Cache for $PANTHEON_ENV
drush @${SITE_CODE}.${PANTHEON_ENV} cr
