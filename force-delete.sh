#!/usr/bin/env bash

# This is only required if there are releases created for the project,
# otherwise terraform can handle it

outputs=$(terraform output -json)

space=$(echo $outputs | jq -r '.space.value')
project_names=$(echo $outputs | jq -r '.project_names.value[]')

for project_name in $project_names; do
  echo "Deleting $project_name from $space"
  octopus --space $space project delete $project_name -y
done

# Remove poorly supported items from state manually
project_indexes=$(echo $outputs | jq -r '.project_indexes.value[]')
for project_index in $project_indexes; do
  terraform state rm "module.project[\"$project_index\"].octopusdeploy_project_scheduled_trigger.main[\"trigger\"]"
done

terraform destroy
