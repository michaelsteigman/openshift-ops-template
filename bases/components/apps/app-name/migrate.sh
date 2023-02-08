#!/bin/bash
set -e

echo "Build info:"
echo "==========="
echo "Commit ID: ${OPENSHIFT_BUILD_COMMIT}"
echo "Name: ${OPENSHIFT_BUILD_NAME}"
echo "Git Tag: `git describe --tags`"

# Waiting for 3.1 and the --check option

# Check for unapplied migrations
# python /opt/app-root/src/manage.py migrate --check 2> /dev/null || true

# if [[ $? -eq 0 ]]; then
#     echo -n "No migrations to run."
# else
#     echo "Found unapplied migrations. Running migrate..."
#     python /opt/app-root/src/manage.py migrate --noinput
#     echo -n "Migration Completed."
# fi

echo ""
echo "Running 'manage.py migrate'."
echo "==========="
python /opt/app-root/src/manage.py migrate --noinput
echo "==========="
echo "Exiting migration script."
exit 0
