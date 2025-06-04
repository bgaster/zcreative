# pd2json.sh convert PD file to JSON
#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <input_file.pd> <output_file.json>"
  echo "Example: $0 document.pd"
  exit 1
fi

# Get the directory of the executing script
script_dir=$(dirname "$0")

input_file="$1"

# Check if the input file exists
if [ ! -f "$input_file" ]; then
  echo "Error: File '$input_file' not found."
  exit 1
fi

node "$script_dir/pd2json.js" "$input_file" | jq . 
