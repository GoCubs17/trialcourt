#!/bin/bash

# A helper script for installing new multisites.

set -e

# Reset in case getopts has been used previously in the shell.
OPTIND=1

R="\033[31m"
G="\033[32m"
Y="\033[33m"
RE="\033[0m"

NEW=$1
NOPROXY=false
NODB=false

if [ "$NEW" = '' ] ; then
  echo -e "\n${R}No new site code provided.${RE}
  \n Run this command with a short project code as an argument i.e. slo
  \n ${Y}lando multisite slo${RE}"
  exit 1
fi

if [ -d /app/web/sites/${NEW} ] ; then
  echo -e "\n${R}Aborting. This directory already exists: /app/web/sites/${NEW}${RE}"
  exit 1
fi

if grep -Fq "tc-${NEW}.lndo.site" /app/.lando.yml
then
  echo "\nProxy Detected in .lando.yml"
else
  echo -e "\n - ${R}No proxy ${RE}tc-${NEW}.lndo.site${R} detected in .lando.yml.${RE}"
  NOPROXY=true
fi

if grep -Fq "db${NEW}" /app/.lando.yml
then
  echo "\nDatabase Services for db${NEW} detected in .lando.yml"
else
  echo -e "\n - ${R}No Database Services for ${RE}db${NEW}${R} detected in .lando.yml${RE}"
  NODB=true
fi

if $NODB || $NOPROXY
then
  echo -e "\nMake sure you update the .lando.yml file and run ${Y}lando rebuild${RE}.\n"
  exit 1
fi

echo -e "\n${G}Creating new multisite: ${NEW}${RE}\n"

echo "\$sites['tc-${NEW}.lndo.site'] = '${NEW}';" >> /app/web/sites/sites.php
cp -r /app/web/sites/default /app/web/sites/$NEW
rm -rf /app/web/sites/${NEW}/files
mkdir /app/config/config-${NEW}-local

# Replace variables in settings.local.php
sed -i "s/'host' => 'database'/'host' => 'db${NEW}'/g" /app/web/sites/${NEW}/settings.local.php

# Replace variables in settings.pantheon.php
sed -i "s/CONFIG_SYNC_DIRECTORY => '..\/config\/config-default'/CONFIG_SYNC_DIRECTORY => '..\/config\/config-${NEW}'/g" /app/web/sites/${NEW}/settings.pantheon.php

sed -i "s/'sites\/default'/'sites\/${NEW}'/g" /app/web/sites/${NEW}/settings.pantheon.php

# Replace variables in settings.php
sed -i "s/'..\/config\/config-default'/'..\/config\/config-${NEW}'/g" /app/web/sites/${NEW}/settings.php

sed -i "s/'..\/config\/config-default-local'/'..\/config\/config-${NEW}-local'/g" /app/web/sites/${NEW}/settings.php

echo -e "\n${G}Multisite directory configured... now running installation. This will take a while...${RE}"

cd /app
drush si -l tc-${NEW}.lndo.site -vvv --site-name="SITE NAME" --account-mail="jcc@example.com" --account-name="JCC" --account-mail="jcc@example.com"

drush cex -y -l tc-${NEW}.lndo.site

if [ -f /app/config/config-${NEW}/config_split.config_split.local.yml ] ; then
  echo -e "\nUpdating split local."
  sed -i "s/\/config\/config-default-local/\/config\/config-${NEW}-local/g" /app/config/config-${NEW}/config_split.config_split.local.yml
fi

drush uli -l tc-${NEW}.lndo.site --druplicon

echo -e "\n${G}Installation complete!${RE}
  If everything worked, you should be able to access it with the link above."
