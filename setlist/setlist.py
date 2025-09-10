#!/usr/bin/env python3

from pathlib import Path
import os
# import sys
import subprocess
import tempfile
from datetime import datetime
from shutil import copy2
import argparse

########################### EXTERNAL DEPENDENCIES #########################
# Requires pandoc, pdftk
text_editor = "geany" # or pick another text editor
file_manager = "nemo" # or pick another file manager

########################### PATHS #########################################
# The file list saved from nnn file manager
selection_file = r"/home/harry/.config/nnn/selection"   
# Setlist page is the tunes table of contents
setlist_path = "/home/harry/Documents/Band/setlist.pdf"
output_path = "/home/harry/Documents/Band/setlists/"
pdf_finder = "/home/harry/bin/python/music-chart-tools/setlist/pdffinder.py"
########################### FUNCTIONS #######################################

def create_setlist():
    ''' 
    Create a numbered setlist sheet from the tunes in the selection file.
    
    Setlist.pdf will become the first page of the output PDF.
    '''
    global selection_file
    #selection_file = r"/home/harry/.config/nnn/selection"
    tune_number = 0

    # delete old setlist.pdf
    if os.path.exists(setlist_path):
        os.remove(setlist_path)    

    # Read tunes
    if not os.path.exists(selection_file):
        print(f"Error: Selection file {selection_file} not found")
        list_backups()
        choice = input("Choose a backup (number) or 't' to run pdffinder: ").strip()
        if choice.isdigit():
            backup_path = use_backup(int(choice))
            if backup_path and os.path.exists(backup_path):
                selection_file = backup_path  # Update the selection_file to point to the restored backup
            else:
                print("Error: Failed to restore backup")
                return
        elif choice == 't':   
            # run pdffinder.py
            subprocess.run(["python3", pdf_finder])  #  I should import pdffinder.py directly
            return        
        else:
            print("Invalid selection")
            return
    try:
        with open(selection_file, 'r') as f:
            tunes = f.read().splitlines()
    except Exception as e:
        print(f"Error reading selection file: {e}")
        return
    
    # Create a temporary file to write the setlist
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.md') as temp_file:
        temp_file.write("# Setlist\n\n")
        for tune in tunes:
            tune_number += 1
            temp_file.write(f"## {tune_number}. {Path(tune).stem}\n")
        temp_file.flush()  # Ensure all data is written

        # Convert to PDF using pandoc
        output_pdf = setlist_path
        # Explicitly specify the input format as markdown
        subprocess.run(["pandoc", "-f", "markdown", temp_file.name, "-o", output_pdf])
    
    # Clean up the temporary file
    os.unlink(temp_file.name)

def number_pages(output_file):
    '''
     Open iLovePDF page numbering website and the PDF in Nemo
    '''
    subprocess.run([file_manager, output_file])   # show output file in browser
    #subprocess.run(['nautilus', output_file])   # show output file in browser
    choice = input("Go to IlovePDF site? (y/n): ").lower()
    if choice in ['y', 'yes']:
        import webbrowser
        webbrowser.open('https://www.ilovepdf.com/add_pdf_page_number')

def copy_list(output_file):
    # copy the nnn tunelist to a backup file with the same name 
    basename = os.path.basename(output_file).split(".")[0]
    selection_copy = os.path.join(output_path, f"{basename}.txt")
    copy2(selection_file, selection_copy)
    return selection_copy
    
def compile_setlist(output_file=None):
    '''
    Compile all the tunes in the setlist into a single PDF, including setlist.pdf as the first page.

    The tunes will be added in the order they appear in the selection file.
    If no output file name is provided, the default output file name is Setlist_YYYYMMDD.pdf.
    If an output file name is provided, it will be used as the output file name.
    '''
  
    # Verify input files exist
    if not os.path.exists(setlist_path):
        print(f"Error: First page file {setlist_path} not found")
        return
    if not os.path.exists(selection_file):
        print(f"Error: Selection file {selection_file} not found")
        return
    
    # Set default output file if none provided
    if output_file is None:
        date_str = datetime.now().strftime("%Y-%m-%d")
        output_file = os.path.join(output_path, f"Setlist_{date_str}.pdf")
    else:
        # If output_file is provided but not an absolute path, make it relative to output_path
        if not os.path.isabs(output_file):
            output_file = os.path.join(os.path.dirname(output_path), output_file+".pdf")

    # Backup copy of nnn set list    
    selection_copy = copy_list(output_file)

    print("Where everything is:")
    print("\n"+"="*50)
    print(f"Output path: {output_path}")
    print(f"Setlist file: {setlist_path}")
    print(f"Selection file: {selection_file}")
    print(f"Output file: {output_file}")
    print(f"Selection copy: {selection_copy}")
    print("="*50+"\n")
    
    # Prompt the user to edit the selection file
    choice = input("Edit selection file? (y/n): ").lower()
    if choice in ['y', 'yes']:
        # Open the selection file for editing
        subprocess.run([text_editor, "--new-instance", selection_file])
        
        # Compile the PDF using the selection file
    try:
        with open(selection_file, 'r') as f:
            selection_content = f.read().strip()
            selection_content = setlist_path + "\n" + selection_content
        if selection_content:
            # Split the content into individual file paths
            pdf_files = selection_content.split()
            # Build the pdftk command with all files
            pdftk_cmd = ["pdftk"] + pdf_files + ["cat", "output", output_file]
            subprocess.run(pdftk_cmd)
            number_pages(output_file)
    except FileNotFoundError:
        print(f"Error: Selection file {selection_file} not found")
    except Exception as e:
        print(f"An error occurred: {e}")

def list_backups(show_instructions=False):
    """List all backup files in the output directory"""
    print("\nAvailable backup files:")
    print("-" * 50)
    for i, file in enumerate(sorted(Path(output_path).glob('*.txt')), 1):
        print(f"{i}. {file.name}")
    if show_instructions == True:    
        print("\nTo use a backup, run:")
        print("  python setlist.py --use-backup <number>")
        print("  or")
        print("  python setlist.py -u <number>")

def use_backup(backup_num):
    '''
    Restore a specific backup file as the current selection
    
    Args:
        backup_num (int): The number of the backup file to restore
    
    Returns:
        str: Path to the restored backup file if successful, None otherwise
    '''
    try:
        backup_files = sorted(Path(output_path).glob('*.txt'))
        if not backup_files:
            print("No backup files found.")
            return None
            
        if 1 <= backup_num <= len(backup_files):
            selected_backup = str(backup_files[backup_num - 1])
            copy2(selected_backup, selection_file)
            print(f"Restored backup: {selected_backup}")
            return selected_backup
        else:
            print("Invalid backup number")
            return None
    except Exception as e:
        print(f"Error restoring backup: {e}")
        return None

if __name__ == "__main__":
    os.system('cls' if os.name == 'nt' else 'clear')
    parser = argparse.ArgumentParser(description='Manage setlists and backups')
    parser.add_argument('output_file', nargs='?', default=None,
                      help='Optional output PDF filename')
    parser.add_argument('--list-backups', '-l', action='store_true', 
                       help='List all available backup files')
    parser.add_argument('--use-backup', '-u', type=int,
                       help='Use a specific backup file by number')
    
    args = parser.parse_args()
    
    if args.list_backups:
        list_backups(show_instructions=True)
    elif args.use_backup is not None:
        if use_backup(args.use_backup):
            create_setlist()
            compile_setlist(args.output_file)
    else:
        # Default behavior - create new setlist and compile it
        create_setlist()
        compile_setlist(args.output_file)