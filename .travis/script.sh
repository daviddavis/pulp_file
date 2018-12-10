#!/usr/bin/env bash
# coding=utf-8
set -veuo pipefail

# check the commit message
./.travis/check_commit.sh

# Lint code.
flake8 --config flake8.cfg || exit 1

# Run migrations.
export DJANGO_SETTINGS_MODULE=pulpcore.app.settings
pulp-manager migrate auth --noinput
pulp-manager makemigrations pulp_app --noinput
pulp-manager makemigrations pulp_file
pulp-manager migrate --noinput

# Run unit tests.
coverage run `which pulp-manager` test ./pulp_file/tests/unit/

# Run functional tests.
pulp-manager reset-admin-password --password admin
pulp-manager runserver >> ~/django_runserver.log 2>&1 &
rq worker -n 'resource_manager@%h' -w 'pulpcore.tasking.worker.PulpWorker' >> ~/resource_manager.log 2>&1 &
rq worker -n 'reserved_resource_worker_1@%h' -w 'pulpcore.tasking.worker.PulpWorker' >> ~/reserved_worker-1.log 2>&1 &
sleep 5
show_logs_and_return_non_zero() {
    readonly local rc="$?"
    cat ~/django_runserver.log
    cat ~/resource_manager.log
    cat ~/reserved_worker-1.log
    return "${rc}"
}
pytest -v -r sx --color=yes --pyargs pulp_file.tests.functional || show_logs_and_return_non_zero

# test against pulpcore as well since pulpcore has a set of tests which use pulp_file
cd ../pulp
pytest -v -r sx --color=yes --pyargs tests.functional.api.using_plugin || show_logs_and_return_non_zero

# upload coverage reports to codecov
codecov

# Travis' scripts use unbound variables. This is problematic, because the
# changes made to this script's environment appear to persist when Travis'
# scripts execute. Perhaps this script is sourced by Travis? Regardless of why,
# we need to reset the environment when this script finishes.
#
# We can't use `trap cleanup_function EXIT` or similar, because this script is
# apparently sourced, and such a trap won't execute until the (buggy!) calling
# script finishes.
set +euo pipefail
