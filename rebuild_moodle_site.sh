#!/bin/bash

# Site name
SITE_NAME="moodle44"
PHP="8.1"

# Add the site incase it was removed/does not exist
echo "Remove site: $SITE_NAME"
control remove "$SITE_NAME"

# Add the site incase it was removed/does not exist
echo "Adding site: $SITE_NAME"
control add "$SITE_NAME" --php "$PHP"

# Wait for sites to warm up
echo "Waiting for sites to warm up..."
sleep 5

# Install the site
control install "$SITE_NAME" --sitename "$SITE_NAME"

#For each mbz file in the current directory
for mbz in ./*.mbz; do
    echo "Restoring backup: $mbz"
    
    # Get just the filename without path
    filename=$(basename "$mbz")
    
    # Copy the mbz file to the container
    echo "Copying $mbz to container..."
    docker cp "$mbz" "$SITE_NAME":/tmp/
    
    # Restore the backup using the copied file
    echo "Restoring $filename in container..."
    docker exec -it "$SITE_NAME" php admin/cli/restore_backup.php --file="/tmp/$filename" --categoryid=1
    
    # Optional: Clean up the copied file from container
    docker exec "$SITE_NAME" rm "/tmp/$filename"    
done

# Enable guest access for a specific course (course ID 2)
docker exec "$SITE_NAME" php -r "
define('CLI_SCRIPT', true);
require_once('/var/www/$SITE_NAME/config.php');
require_once('/var/www/$SITE_NAME/lib/setup.php');
global \$DB;
\$DB->set_field('enrol', 'status', 0, array('courseid' => 2, 'enrol' => 'guest'));
"

# Configure auto guest login
echo "Configuring auto guest login..."
docker exec "$SITE_NAME" php admin/cli/cfg.php --name=autologinguests --set=1

# Purge caches just in case.
echo "Purging caches..."
docker exec "$SITE_NAME" php admin/cli/purge_caches.php

# Run load test
echo "Run benchmarking..."
# Look like the first request return more data than subsequent ones, then cause lots of fail request
# Ignore the first request
ab -n 1 https://"$SITE_NAME".localhost/course/view.php?id=2
ab -n 100 https://"$SITE_NAME".localhost/course/view.php?id=2 > $SITE_NAME

