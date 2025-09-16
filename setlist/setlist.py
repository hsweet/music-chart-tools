#!/usr/bin/env python3
"""
Setlist tools for managing PDF music charts and creating setlists.

This module provides functionality to:
- Create numbered setlists from the tunes in the selection file
- Compile multiple PDFs into a single setlist document
- Manage backups of setlist selections
- pdffinder.py can be run as a separate script to choose pdf files for the setlist.

Switches:
    -p, --run-pdffinder
    -l, --list-backups
    -u, --use-backup <number>
    -i, --instructions
"""

from pathlib import Path
import os
import subprocess
import tempfile
from datetime import datetime
from shutil import copy2
import argparse
from io import BytesIO

########################### CONFIGURATION #################################
# Centralized configuration for easy customization and future sharing
CONFIG = {
    # External dependencies
    'text_editor': "geany",  # or pick another text editor
    'file_manager': "nemo",  # or pick another file manager (nautilus)
    'pdf_viewer': "evince",  # or pick another PDF viewer (evince)
    
    # File paths - change these to match your system
    'selection_file': os.path.expanduser("~/.config/nnn/selection"),   # nnn's default selection file
    'setlist_path': os.path.expanduser("~/Documents/Band/setlist.pdf"),  # tunes table of contents
    'output_path': os.path.expanduser("~/Documents/Band/setlists/"),
    'pdf_finder': os.path.expanduser("~/bin/python/music-chart-tools/setlist/pdffinder.py"),
    'required_tools': ['pandoc', 'pdftk'],
    'optional_python_libs': ['PyPDF2', 'reportlab'],
    
    # External tool configurations with purpose-based constants
    'setlist_generator': {
        'cmd': 'pandoc',
        'format_param': 'markdown',
        'output_flag': '-o'
    },
    'pdf_merger': {
        'cmd': 'pdftk',
        'merge_operation': 'cat',
        'output_param': 'output'
    }
}

# Extract configuration variables from dictionary for backward compatibility
text_editor = CONFIG['text_editor']
file_manager = CONFIG['file_manager']
setlist_path = CONFIG['setlist_path']
output_path = CONFIG['output_path']
pdf_finder = CONFIG['pdf_finder']

########################### FUNCTIONS #######################################

def create_setlist(selection_file=None,title="TestTitle"):
    ''' 
    Create a numbered setlist sheet from the tunes in the selection file.
    The path is removed to get the tune name.
    
    Args:
        selection_file (str, optional): Path to selection file. 
            Defaults to CONFIG['selection_file']
    
    Returns:
        str: The actual selection file path that was used
    
    Setlist.pdf will become the first page of the output PDF.
    '''
    # Use default if not provided
    if selection_file is None:
        selection_file = CONFIG['selection_file']
    tune_number = 0

    # delete old setlist.pdf
    if os.path.exists(CONFIG['setlist_path']):
        os.remove(CONFIG['setlist_path'])    

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
                return selection_file
        elif choice == 't':   
            # run pdffinder.py
            if not _run_validated_subprocess(["python3", CONFIG['pdf_finder']], "Running PDF finder"):
                print("Error: Failed to run PDF finder")
            return selection_file        
        else:
            print("Invalid selection")
            return selection_file
    try:
        with open(selection_file, 'r') as f:
            tunes = f.read().splitlines()
    except Exception as e:
        print(f"Error reading selection file: {e}")
        return selection_file
    
    # Create a temporary file to write the setlist
    with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.md') as temp_file:
        temp_file.write(f"# {title.title()}\n\n")
        for tune in tunes:
            tune_number += 1        
            temp_file.write(f"## {tune_number}. {Path(tune).stem}\n")
        temp_file.flush()  # Ensure all data is written

        # Convert to PDF using pandoc
        output_pdf = CONFIG['setlist_path']
        # Explicitly specify the input format as markdown
        setlist_gen = CONFIG['setlist_generator']
        if not _run_validated_subprocess([setlist_gen['cmd'], "-f", setlist_gen['format_param'], temp_file.name, setlist_gen['output_flag'], output_pdf], 
                                       "Writing setlist page"):
            print("Error: Failed to write setlist page")
            return selection_file
    
    # Clean up the temporary file
    os.unlink(temp_file.name)
    
    return selection_file

def number_pages(output_file):
    '''
     Add page numbers to PDF locally using PyPDF2 and ReportLab
     Falls back to web-based numbering if local method fails
    '''
    try:
        # Import required libraries
        import PyPDF2
        from reportlab.pdfgen import canvas
        from reportlab.lib.pagesizes import letter
        
        print("Adding page numbers to PDF...")
        
        # Create a temporary file for the output
        with tempfile.NamedTemporaryFile(mode='wb', suffix='.pdf', delete=False) as tmp_file:
            tmp_output_path = tmp_file.name
        
        # Add page numbers using the working implementation
        _add_page_numbers_to_pdf(output_file, tmp_output_path, PyPDF2, canvas, letter)
        
        # Replace the original file with the numbered version
        if os.path.exists(tmp_output_path):
            # Backup the original file first
            backup_path = output_file + '.backup'
            if os.path.exists(output_file):
                import shutil
                shutil.move(output_file, backup_path)
            
            # Move the numbered file to the original location
            import shutil
            shutil.move(tmp_output_path, output_file)
            
            # Remove the backup
            if os.path.exists(backup_path):
                os.remove(backup_path)
            
            print(f"Page numbers added successfully to {output_file}")
        else:
            raise Exception("Failed to create numbered PDF")
            
    except ImportError:
        print("Error: Required libraries not found.")
        print("Please install them with:")
        print("sudo apt install python3-pypdf2 python3-reportlab")
        print("\nFalling back to web-based page numbering...")
        _fallback_to_web_numbering(output_file)
    except Exception as e:
        print(f"Error adding page numbers locally: {e}")
        print("\nFalling back to web-based page numbering...")
        _fallback_to_web_numbering(output_file)

def _add_page_numbers_to_pdf(input_pdf, output_pdf, PyPDF2, canvas, letter):
    """
    Add page numbers to a PDF using PyPDF2 and ReportLab
    Skips the first page (setlist) and starts numbering from page 2
    Based on the working number_pages.py script
    """
    # Create a new PDF, but just with page numbers.
    packet = BytesIO()
    can = canvas.Canvas(packet, pagesize=letter)
    can.setFont('Helvetica', 12)
    pdf = PyPDF2.PdfReader(input_pdf)
    
    # Skip the first page (setlist) and start numbering from page 2
    for page_num in range(len(pdf.pages)):
        if page_num == 0:
            # First page (setlist) - no page number
            can.showPage()
        else:
            # Pages 2 and beyond - add page numbers
            page_width = letter[0]
            page_number = page_num  # This will be 1, 2, 3, etc. for pages 2, 3, 4, etc.
            text_width = can.stringWidth(str(page_number), 'Helvetica', 12)
            can.drawString(page_width - text_width - 30, 30, str(page_number))
            can.showPage()
    can.save()

    # Combine the original PDF with the page numbers.
    packet.seek(0)
    new_pdf = PyPDF2.PdfReader(packet)
    pdf_writer = PyPDF2.PdfWriter()
    for page_num in range(len(pdf.pages)):
        page = pdf.pages[page_num]
        page.merge_page(new_pdf.pages[page_num])
        pdf_writer.add_page(page)
    with open(output_pdf, 'wb') as f:
        pdf_writer.write(f)

def _fallback_to_web_numbering(output_file):
    '''
     Fallback to web-based page numbering if local method fails
    '''
    if not _run_validated_subprocess([CONFIG['file_manager'], output_file], "Opening file manager"):
        print("Error: Failed to open file manager")
        return
    choice = input("Go to IlovePDF site? (y/n): ").lower()
    if choice in ['y', 'yes']:
        import webbrowser
        webbrowser.open('https://www.ilovepdf.com/add_pdf_page_number')

def copy_list(output_file, selection_file=None):
    # copy the nnn tunelist to a backup file with the same name 
    if selection_file is None:
        selection_file = CONFIG['selection_file']
    basename = os.path.basename(output_file).split(".")[0]
    selection_copy = os.path.join(CONFIG['output_path'], f"{basename}.txt")
    copy2(selection_file, selection_copy)
    return selection_copy
    
def _validate_external_tools():
    """Validate that required external tools are available"""
    required_tools = CONFIG['required_tools'] + [CONFIG['file_manager']]
    # text_editor is optional for validation since it's handled specially in _run_validated_subprocess
    missing_tools = []
    
    for tool in required_tools:
        try:
            # Use 'which' command to check if tool exists
            result = subprocess.run(['which', tool], 
                                  capture_output=True, 
                                  text=True, 
                                  timeout=5)
            if result.returncode != 0:
                missing_tools.append(tool)
        except (subprocess.TimeoutExpired, FileNotFoundError):
            missing_tools.append(tool)
    
    if missing_tools:
        print(f"Error: Missing required tools: {', '.join(missing_tools)}")
        print("Please install the missing tools and try again.")
        return False
    return True

def _run_validated_subprocess(cmd, description="", wait_for_completion=False):
    """Run subprocess command with validation and error handling"""
    if description:
        print(f"Running: {description}")
    
    # Check if this is a command that should not timeout
    is_text_editor = len(cmd) > 0 and cmd[0] == CONFIG['text_editor']
    is_file_manager = len(cmd) > 0 and cmd[0] == CONFIG['file_manager']
    is_pdf_viewer = len(cmd) > 0 and cmd[0] == CONFIG['pdf_viewer']
    
    try:
        # For text editors and file managers, use Popen to run without blocking
        # unless wait_for_completion is True
        if is_text_editor or is_file_manager or is_pdf_viewer:
            if wait_for_completion:
                # Wait for the process to complete (for text editor when editing selection file)
                result = subprocess.run(cmd, check=True)
                if result.stdout:
                    print(result.stdout)
            else:
                # Use Popen to start the process without waiting for it to complete
                # Redirect stderr to /dev/null to suppress GTK theme warnings
                with open(os.devnull, 'w') as devnull:
                    process = subprocess.Popen(cmd, stderr=devnull)
                print(f"Started {cmd[0]} (PID: {process.pid}) - program will continue")
        else:
            result = subprocess.run(cmd, check=True, capture_output=True, text=True, timeout=30)
            if result.stdout:
                print(result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {' '.join(cmd)}")
        print(f"Return code: {e.returncode}")
        if hasattr(e, 'stderr') and e.stderr:
            print(f"Error output: {e.stderr}")
        return False
    except subprocess.TimeoutExpired:
        print(f"Timeout running command: {' '.join(cmd)}")
        return False
    except FileNotFoundError:
        print(f"Command not found: {cmd[0]}")
        return False
    except Exception as e:
        print(f"Unexpected error running command: {e}")
        return False

def _validate_inputs():
    """Validate that required input files exist and external tools are available"""
    # Validate files
    if not os.path.exists(CONFIG['setlist_path']):
        print(f"Error: First page file {CONFIG['setlist_path']} not found")
        return False
    if not os.path.exists(CONFIG['selection_file']):
        print(f"Error: Selection file {CONFIG['selection_file']} not found")
        return False
    
    # Validate external tools
    if not _validate_external_tools():
        return False
    
    return True

def _setup_output_file(output_file):
    """Set up the output file path"""
    if output_file is None:
        date_str = datetime.now().strftime("%Y-%m-%d")
        return os.path.join(CONFIG['output_path'], f"Setlist_{date_str}.pdf")
    else:
        if not os.path.isabs(output_file):
            return os.path.join(os.path.dirname(CONFIG['output_path']), output_file + ".pdf")
        return output_file

def _show_paths(output_file, selection_copy, selection_file=None):
    """Display debug information about paths and files"""
    if selection_file is None:
        selection_file = CONFIG['selection_file']
    print("Where everything is:")
    print("\n" + "=" * 50)
    print(f"Output path: {CONFIG['output_path']}")
    print(f"Setlist file: {CONFIG['setlist_path']}")
    print(f"Selection file: {selection_file}")
    print(f"Output file: {output_file}")
    print(f"Selection copy: {selection_copy}")
    print("=" * 50 + "\n")
    print(__doc__ + "\n")

def _handle_user_editing(selection_file=None):
    """Handle user choice to edit the selection file"""
    if selection_file is None:
        selection_file = CONFIG['selection_file']
    choice = input("Edit song list? (y/n): ").lower()
    if choice in ['y', 'yes']:
        if not _run_validated_subprocess([CONFIG['text_editor'], "--new-instance", selection_file], "Opening text editor", wait_for_completion=True):
            print("Error: Failed to open text editor")

def _get_pdf_files_list(selection_file=None):
    """Read selection file and prepare list of PDF files"""
    if selection_file is None:
        selection_file = CONFIG['selection_file']
    with open(selection_file, 'r') as f:
        selection_content = f.read().strip()
        selection_content = CONFIG['setlist_path'] + "\n" + selection_content
    return selection_content.split() if selection_content else []

def _run_merge_pdf_command(pdf_files, output_file):
    """Execute the pdftk command to merge PDFs"""
    pdf_merger = CONFIG['pdf_merger']
    pdftk_cmd = [pdf_merger['cmd']] + pdf_files + [pdf_merger['merge_operation'], pdf_merger['output_param'], output_file]
    if not _run_validated_subprocess(pdftk_cmd, "Merging PDF files with pdftk"):
        print("Error: Failed to merge PDF files")
        return False
    return True

def _compile_pdf(output_file, selection_file=None):
    """Compile the PDF using pdftk"""
    if selection_file is None:
        selection_file = CONFIG['selection_file']
    try:
        pdf_files = _get_pdf_files_list(selection_file)
        if pdf_files:
            if _run_merge_pdf_command(pdf_files, output_file):
                number_pages(output_file)
                #_fallback_to_web_numbering(output_file)
            else:
                print("Error: PDF compilation failed")
        else:
            print("Error: No PDF files found to compile")
    except FileNotFoundError:
        print(f"Error: Selection file {selection_file} not found")
    except Exception as e:
        print(f"An error occurred: {e}")

def compile_setlist(output_file=None, selection_file=None):
    '''
    Compile all the tunes in the setlist into a single PDF, including setlist.pdf as the first page.

    Args:
        output_file (str, optional): Output PDF filename
        selection_file (str, optional): Path to selection file. 
                                      Defaults to CONFIG['selection_file']

    The tunes will be added in the order they appear in the selection file.
    If no output file name is provided, the default output file name is Setlist_YYYYMMDD.pdf.
    If an output file name is provided, it will be used as the output file name.
    '''
    # Use default selection_file if not provided
    if selection_file is None:
        selection_file = CONFIG['selection_file']
    
    # Validate inputs
    if not _validate_inputs():
        return
    
    # Set up output file
    output_file = _setup_output_file(output_file)
    
    # Create backup
    selection_copy = copy_list(output_file, selection_file)
    
    # Show paths info
    #_show_paths(output_file, selection_copy, selection_file)
    
    # Handle user editing
    _handle_user_editing(selection_file)
    
    # Compile PDF
    _compile_pdf(output_file, selection_file)

def list_backups(show_instructions=False):
    """List all backup files in the output directory"""
    print("\nAvailable backup files:")
    print("-" * 50)
    for i, file in enumerate(sorted(Path(CONFIG['output_path']).glob('*.txt')), 1):
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
        backup_files = sorted(Path(CONFIG['output_path']).glob('*.txt'))
        if not backup_files:
            print("No backup files found.")
            return None
            
        if 1 <= backup_num <= len(backup_files):
            selected_backup = str(backup_files[backup_num - 1])
            copy2(selected_backup, CONFIG['selection_file'])
            print(f"Restored backup: {selected_backup}")
            return selected_backup
        else:
            print("Invalid backup number")
            return None
    except Exception as e:
        print(f"Error restoring backup: {e}")
        return None

def test_helper_functions():
    """Test all helper functions individually"""
    print("Testing helper functions...")
    print("=" * 50)
    
    # Test _validate_inputs
    print("\n1. Testing _validate_inputs():")
    result = _validate_inputs()
    print(f"Validation result: {result}")
    
    # Test _validate_external_tools
    print("\n2. Testing _validate_external_tools():")
    tools_result = _validate_external_tools()
    print(f"External tools validation: {tools_result}")
    
    # Test _setup_output_file
    print("\n3. Testing _setup_output_file():")
    test_output = _setup_output_file(None)
    print(f"Default output file: {test_output}")
    
    custom_output = _setup_output_file("test_setlist")
    print(f"Custom output file: {custom_output}")
    
    # Test _show_debug_info (requires a selection_copy)
    print("\n4. Testing _show_debug_info():")
    test_copy = "/tmp/test_selection.txt"
    _show_paths(test_output, test_copy)
    
    # Test _get_pdf_files_list (if selection file exists)
    print("\n5. Testing _get_pdf_files_list():")
    try:
        pdf_files = _get_pdf_files_list()
        print(f"PDF files list: {pdf_files}")
    except Exception as e:
        print(f"Error getting PDF files: {e}")
    
    # Test _run_validated_subprocess with a simple command
    print("\n6. Testing _run_validated_subprocess():")
    test_result = _run_validated_subprocess(["echo", "test"], "Testing echo command")
    print(f"Subprocess test result: {test_result}")
    
    print("\n" + "=" * 50)
    print("Helper function testing complete!")

if __name__ == "__main__":
    os.system('cls' if os.name == 'nt' else 'clear')

    parser = argparse.ArgumentParser(description='Manage setlists and backups')
    parser.add_argument('output_file', nargs='?', default=None,
                      help='Optional output PDF filename (also used as setlist title)')
    parser.add_argument('--list-backups', '-l', action='store_true', 
                       help='List all available backup files')
    parser.add_argument('--use-backup', '-u', type=int,
                       help='Use a specific backup file by number')
    parser.add_argument('--run-pdffinder', '-p', action='store_true', 
                       help='Choose files for setlist to use')
    parser.add_argument('--instructions', '-i', action='store_true', 
                       help='Show instructions')
    parser.add_argument('--test-helpers', action='store_true', 
                       help='Test helper functions')
    
    args = parser.parse_args()
    
    if args.test_helpers:
        test_helper_functions()
    elif args.list_backups:
        list_backups(show_instructions=True)
    elif args.use_backup is not None:
        if use_backup(args.use_backup):
            # Get the actual output filename and use it as the title
            output_file = _setup_output_file(args.output_file)
            title = Path(output_file).stem  # Extract filename without extension
            selection_file = create_setlist(title=title)
            compile_setlist(args.output_file, selection_file)
            _run_validated_subprocess([CONFIG['pdf_viewer'], output_file], "Opening PDF viewer")
    elif args.run_pdffinder:
        if not _run_validated_subprocess(["python3", CONFIG['pdf_finder']], "Running PDF finder"):
            print("Error: Failed to run PDF finder")
    elif args.instructions:
        print(__doc__)
        _show_paths()
       
    else:
        # Default behavior - create new setlist and compile it
        # Get the actual output filename and use it as the title
        output_file = _setup_output_file(args.output_file)
        title = Path(output_file).stem  # Extract filename without extension
        selection_file = create_setlist(title=title)
        compile_setlist(args.output_file, selection_file)
        _run_validated_subprocess([CONFIG['pdf_viewer'], output_file], "Opening PDF viewer")
