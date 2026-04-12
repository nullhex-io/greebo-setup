#!/usr/bin/env bash
# Auto-format after Edit/Write tool use
# Reads tool info from stdin, runs eslint --fix on changed files

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only trigger on Edit or Write
if [[ "$tool_name" != "Edit" && "$tool_name" != "Write" ]]; then
  exit 0
fi

# Only format TS/JS files
if [[ ! "$file_path" =~ \.(ts|tsx|js|jsx|mjs)$ ]]; then
  exit 0
fi

# Only format if file is in a project with eslint
project_dir=$(dirname "$file_path")
while [[ "$project_dir" != "/" ]]; do
  if [[ -f "$project_dir/eslint.config.mjs" || -f "$project_dir/.eslintrc.json" || -f "$project_dir/.eslintrc.js" ]]; then
    cd "$project_dir"
    npx eslint --fix "$file_path" 2>/dev/null
    exit 0
  fi
  project_dir=$(dirname "$project_dir")
done
