#!/bin/bash

FILE_LIST="./bin/migrations-and-tasks-list.txt"

# For testing purposes
#FILE_LIST="./bin/migrations-sample-list.txt"

echo "Processing data migrations and after party tasks..."
while IFS= read -r file
do
  if [[ $file == *.rb ]]
  then
    echo ""
    echo "Migration $file"
    ./bin/rails db:migrate:up VERSION="${file::14}"
  elif [[ $file == *.rake ]]
  then
    echo ""
    name=${file%.*}
    suffix=${name: -5}
    if [[ $suffix == _spec ]]
    then
      echo "Task spec ${file}"
      ./bin/rake spec/lib/tasks/deployment/${file}
    else
      echo "Task after_party ${name:15}"
      ./bin/rake after_party:${name:15}
    fi
  fi
done < $FILE_LIST
echo ""
echo "Processing data done."
