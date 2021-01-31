#!/usr/bin/env bash

# TODO: convert file to pulp-cli once the filesystem exporter commands are implemented

export TASK_URL=$(http POST $BASE_ADDR$EXPORTER_HREF'exports/' publication=$PUBLICATION_HREF \
  | jq -r '.task')

# Poll the task
while true
do
  case $(http $BASE_ADDR$TASK_URL | jq -r .state) in
    failed|canceled)
      echo "Task in final state: ${state}"
      exit 1
      ;;
    completed)
      echo "$task_url complete."
      break
      ;;
    *)
      echo "Still waiting..."
      sleep 1
      ;;
  esac
done

echo "Inspecting export at $DEST_DIR"
ls $DEST_DIR
