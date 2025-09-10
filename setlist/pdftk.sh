#!/bin/bash

# Check if an output file name is provided
if [ -z "$1" ]; then
    output_file="combined.pdf"  # Default output file name
else
    output_file="$1"  # Use the provided output file name
fi

# Prompt the user to edit the selection file
read -p "Edit selection file? (y/n): " choice

if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    # Open the selection file for editing and wait for it to close
    geany --new-instance ~/.config/nnn/selection
fi

# Compile the PDF using the selection file
pdftk $(cat ~/.config/nnn/selection) cat output "$output_file"

#geany ~/.config/nnn/selection
#pdftk $(cat ~/.config/nnn/selection) cat output combined.pdf
