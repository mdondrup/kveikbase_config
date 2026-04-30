#!/bin/bash

set -eu

source .env

echo "--- 1. Wiping Database and Resetting Settings ---"
# Set PGPASSWORD to avoid interactive prompts
export PGPASSWORD=$DB_PASS
dropdb -h $DB_HOST -U $DB_USER $DB_NAME --if-exists
createdb -h $DB_HOST -U $DB_USER $DB_NAME

cd $DRUPAL_ROOT/web/sites/default
chmod 755 .
chmod 644 settings.php
cp default.settings.php settings.php

echo "--- 2. Performing Fresh Site Install ---"
cd $DRUPAL_ROOT
$DRUSH_PATH site:install --db-url=pgsql://$DB_USER:$DB_PASS@$DB_HOST/$DB_NAME -y

echo "--- 3. Pointing Drupal to kveikbase_config ---"
# We append this to the end of the newly created settings.php
echo "\$settings['config_sync_directory'] = '$CONFIG_DIR';" >> $DRUPAL_ROOT/web/sites/default/settings.php

echo "--- 3. Aligning Site Identity (UUID) ---"
$DRUSH_PATH config:set system.site uuid $SOURCE_UUID -y

echo "--- 4. Pre-installing Tripal and Dependencies ---"
# This ensures field types are registered BEFORE the config import
$DRUSH_PATH en tripal tripal_chado geolocation devel_php \
  jquery_ui jquery_ui_autocomplete jquery_ui_menu -y
$DRUSH_PATH  trp-install-chado --schema-name='chado'
$DRUSH_PATH trp-prep-chado --schema-name='chado'

echo "--- 5. Clearing Blockers ---"
# Deletes the default shortcut set that conflicts with imports
$DRUSH_PATH entity:delete shortcut_set -y

echo "--- 6. Final Configuration Import ---"
$DRUSH_PATH cr
$DRUSH_PATH config:import -y

echo "--- 7. Resetting broken theme config ---"
# we need to switch the theme to default
$DRUSH_PATH config:set system.theme default olivero -y
$DRUSH_PATH drush theme:uninstall tara -y
$DRUSH_PATH theme:install tara -y
$DRUSH_PATH config:set system.theme default tara -y
$DRUSH_PATH cr

echo "--- Setup Complete! ---"

