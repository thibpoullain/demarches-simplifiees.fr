#!/usr/bin/env bash
. common_scalingo.sh

if [ $IS_REVIEW_APP ]; then
    export DISABLE_DATABASE_ENVIRONMENT_CHECK=1
    bin/rails db:schema:load
    bin/rails db:migrations:setup
    bin/migrate-data.sh
    bin/rails db:seed
fi

bundle exec rake jobs:schedule jobs:work
