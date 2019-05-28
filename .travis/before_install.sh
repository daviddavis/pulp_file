#!/usr/bin/env sh
set -v

COMMIT_MSG=$(git show HEAD^2 -s)
export COMMIT_MSG
export PULP_PR_NUMBER=$(echo $COMMIT_MSG | grep -oP 'Required\ PR:\ https\:\/\/github\.com\/pulp\/pulpcore\/pull\/(\d+)' | awk -F'/' '{print $7}')
export PULP_PLUGIN_PR_NUMBER=$(echo $COMMIT_MSG | grep -oP 'Required\ PR:\ https\:\/\/github\.com\/pulp\/pulpcore-plugin\/pull\/(\d+)' | awk -F'/' '{print $7}')
export PULP_SMASH_PR_NUMBER=$(echo $COMMIT_MSG | grep -oP 'Required\ PR:\ https\:\/\/github\.com\/PulpQE\/pulp-smash\/pull\/(\d+)' | awk -F'/' '{print $7}')
export PULP_ROLES_PR_NUMBER=$(echo $COMMIT_MSG | grep -oP 'Required\ PR:\ https\:\/\/github\.com\/pulp\/ansible-pulp\/pull\/(\d+)' | awk -F'/' '{print $7}')
export PULP_BINDINGS_PR_NUMBER=$(echo $COMMIT_MSG | grep -oP 'Required\ PR:\ https\:\/\/github\.com\/pulp\/pulp-openapi-generator\/pull\/(\d+)' | awk -F'/' '{print $7}')

# dev_requirements should not be needed for testing; don't install them to make sure
pip install -r test_requirements.txt

# check the commit message
./.travis/check_commit.sh

# Lint code.
flake8 --config flake8.cfg || exit 1

cd ..
git clone https://github.com/pulp/ansible-pulp.git
if [ -n "$PULP_ROLES_PR_NUMBER" ]; then
  cd ansible-pulp
  git fetch origin +refs/pull/$PULP_ROLES_PR_NUMBER/merge
  git checkout FETCH_HEAD
  cd ..
fi

git clone https://github.com/pulp/pulpcore.git

if [ -n "$PULP_PR_NUMBER" ]; then
  cd pulpcore
  git fetch origin +refs/pull/$PULP_PR_NUMBER/merge
  git checkout FETCH_HEAD
  cd ..
fi


git clone https://github.com/pulp/pulpcore-plugin.git

if [ -n "$PULP_PLUGIN_PR_NUMBER" ]; then
  cd pulpcore-plugin
  git fetch origin +refs/pull/$PULP_PLUGIN_PR_NUMBER/merge
  git checkout FETCH_HEAD
  cd ..
fi


if [ -n "$PULP_SMASH_PR_NUMBER" ]; then
  pip uninstall -y pulp-smash
  git clone https://github.com/PulpQE/pulp-smash.git
  cd pulp-smash
  git fetch origin +refs/pull/$PULP_SMASH_PR_NUMBER/merge
  git checkout FETCH_HEAD
  pip install -e .
  cd ..
fi

if [ "$TEST" = 'bindings' ]; then
  git clone https://github.com/pulp/pulp-openapi-generator.git
  cd pulp-openapi-generator

  if [ -n "$PULP_BINDINGS_PR_NUMBER" ]; then
    git fetch origin +refs/pull/$PULP_BINDINGS_PR_NUMBER/merge
    git checkout FETCH_HEAD
  fi
  cd ..
fi

if [ "$DB" = 'mariadb' ]; then
  # working around https://travis-ci.community/t/mariadb-build-error-with-xenial/3160
  mysql -u root -e "DROP USER IF EXISTS 'travis'@'%';"
  mysql -u root -e "CREATE USER 'travis'@'%';"
  mysql -u root -e "CREATE DATABASE pulp;"
  mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'travis'@'%';";
else
  psql -c 'CREATE DATABASE pulp OWNER travis;'
fi

pip install ansible
cp pulp_file/.travis/playbook.yml ansible-pulp/playbook.yml
cp pulp_file/.travis/postgres.yml ansible-pulp/postgres.yml
cp pulp_file/.travis/mariadb.yml ansible-pulp/mariadb.yml

cd pulp_file
