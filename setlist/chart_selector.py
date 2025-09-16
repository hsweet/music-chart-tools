import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import os

# Set a global variable for the default path.
# Or you can use a cross-platform approach to get the user's home directory.
#DEFAULT_PATH = os.path.expanduser('~')
DEFAULT_SOURCE_FOLDER = os.path.expanduser("~/Music/charts/world")    # Source files
DEFAULT_DESTINATION = os.path.expanduser("~/.config/nnn/selection")   # nnn's default selection file"

class FileSelector:
    def __init__(self, root):
        self.root = root
        self.root.title("Selected PDF Files")
        
        # Position the main window
        window_width = 325
        window_height = 600
        screen_width = self.root.winfo_screenwidth()
        screen_height = self.root.winfo_screenheight()
        x = 100
        y = (screen_height - window_height) // 2
        self.root.geometry(f'{window_width}x{window_height}+{x}+{y}')
        
        # Store window position for dialog
        self.root.update_idletasks()
        self.root_x = self.root.winfo_x()
        self.root_y = self.root.winfo_y()
        self.root_width = self.root.winfo_width()
        
        # Create listbox and scrollbar
        list_frame = ttk.Frame(root)
        list_frame.pack(padx=10, pady=5, fill=tk.BOTH, expand=True)
        
        scrollbar = ttk.Scrollbar(list_frame)
        self.listbox = tk.Listbox(
            list_frame, 
            selectmode=tk.SINGLE,
            yscrollcommand=scrollbar.set, 
            width=80, 
            height=15,
            selectbackground='#4A7A8C',
            selectforeground='white',
            activestyle='dotbox',
            exportselection=0
        )
        scrollbar.config(command=self.listbox.yview)
        
        self.listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        # Set up bindings for listbox
        self.listbox.bind('<<ListboxSelect>>', self.on_select)
        self.listbox.bind('<Button-1>', self.on_click)
        self.listbox.bind('<FocusIn>', lambda e: self.listbox.selection_clear(0, tk.END))
        
        # Buttons
        btn_frame = ttk.Frame(root)
        btn_frame.pack(pady=5)
        
        ttk.Button(btn_frame, text="Remove Selected", command=self.remove_file).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="Done", command=self.finish_selection).pack(side=tk.LEFT, padx=5)
        
        # Set up key bindings
        self.listbox.bind('<Key-l>', self.open_selected_pdf)
        self.listbox.bind('<Return>', self.open_selected_pdf)
        self.listbox.focus_set()  # Set focus to the listbox

        self.selected_files = []
        
        # Start file selection automatically
        self.add_file()

            
    def add_file(self):
        # Create a Toplevel window to position the dialog
        self.dialog = tk.Toplevel(self.root)
        self.dialog.withdraw()  # Hide it immediately
        
        # Position the dialog to the right of the main window
        dialog_x = self.root_x + self.root_width + 20  # 20 pixels right of main window
        dialog_y = self.root_y
        self.dialog.geometry(f'800x600+{dialog_x}+{dialog_y}')  # Set initial size
        
        # Configure the style for the file dialog
        style = ttk.Style()
        style.configure('TButton', font=('Arial', 10))
        style.configure('TLabel', font=('Arial', 10))
        
        # Bring the main window back to front
        self.root.lift()
        
        while True:
            file = filedialog.askopenfilename(
                parent=self.dialog,  # Use the hidden toplevel as parent
                title="Select a PDF file (Cancel to finish)",
                initialdir=DEFAULT_SOURCE_FOLDER,
                filetypes=[("PDF files", "*.pdf")],
                initialfile='',
                multiple=False  # Force single file selection
            )
            
            # Make sure main window stays on top
            self.dialog.withdraw()
            self.root.lift()
            
            if not file:  # User clicked Cancel or closed the dialog
                break
                
            if file not in self.selected_files:
                self.selected_files.append(file)
                self.listbox.insert(tk.END, os.path.basename(file))
                self.listbox.see(tk.END)  # Scroll to show the new item
                self.listbox.selection_clear(0, tk.END)
                self.listbox.selection_set(tk.END)
                self.listbox.activate(tk.END)
                self.root.after(100, lambda: self.listbox.focus_set())

    def remove_file(self):
        selection = self.listbox.curselection()
        if selection:
            index = selection[0]
            self.listbox.delete(index)
            del self.selected_files[index]
    
    def finish_selection(self):
        if self.selected_files:
            # Write selected files to the destination file
            with open(DEFAULT_DESTINATION, "w") as f:
                for path in self.selected_files:
                    f.write(path + "\n")
            # Print selected files
            print("Selected PDF files:") 
            for path in self.selected_files:
                print(f"- {path}")
            print(f"\nSelection saved to: {DEFAULT_DESTINATION}")
        else:
            print("No files were selected.")
        # Destroy all windows and end the program
        if hasattr(self, 'dialog') and self.dialog.winfo_exists():
            self.dialog.destroy()
        self.root.destroy()
        self.root.quit()

    def open_selected_pdf(self, event=None):
        """Open the selected PDF file with the system's default PDF viewer."""
        selected_index = self.listbox.curselection()
        if not selected_index:  # No selection
            return None  # Return None to allow default behavior
                
        if not self.selected_files:  # No files in list
            return None
                
        try:
            file_path = self.selected_files[selected_index[0]]
            if os.name == 'nt':  # Windows
                os.startfile(file_path)
            elif os.name == 'posix':  # macOS and Linux
                if os.uname().sysname == 'Darwin':  # macOS
                    os.system(f'open "{file_path}"')
                else:  # Linux
                    os.system(f'xdg-open "{file_path}"')
            return "break"  # Prevent default listbox behavior
        except Exception as e:
            messagebox.showerror("Error", f"Could not open PDF: {str(e)}")
            return "break"
 

    def on_select(self, event=None):
        """Handle selection changes in the listbox"""
        selection = self.listbox.curselection()
        if selection:
            self.listbox.activate(selection[0])

    def on_click(self, event):
        """Handle mouse clicks in the listbox"""
        # Get the index of the clicked item
        index = self.listbox.nearest(event.y)
        if index >= 0:
            self.listbox.selection_clear(0, tk.END)
            self.listbox.selection_set(index)
            self.listbox.activate(index)
            
    def open_selected_pdf2(self):
        """Legacy method, kept for compatibility"""
        self.open_selected_pdf()

############################## End of FileSelector class ##############################

def select_pdf_files():
    """
    Opens a file selection window to allow the user to select multiple PDF files.
    Files are maintained in the exact order they were selected.
    """
    root = tk.Tk()
    root.style = ttk.Style()
    root.style.theme_use('clam')  # Use a modern theme
    
    # Set window size and position (left side of screen)
    window_width = 325
    window_height = 600
    screen_width = root.winfo_screenwidth()
    screen_height = root.winfo_screenheight()
    x = 100  # Fixed position 50px from left
    y = (screen_height - window_height) // 2
    root.geometry(f'{window_width}x{window_height}+{x}+{y}')
    root.minsize(300, 400)  # Prevent window from becoming too small
    
    app = FileSelector(root)
    root.mainloop()

def show_instructions():
    """Display instructions to the user in a message box."""
    instructions = """PDF File Selector
    

1. Double click on a chart to select it
2. Close file selector window when set is complete 
3. Use 'Remove Selected' to remove files if needed
4. Enter or "l" key to view selected file
5. Click 'Done' when finished
6. Selection is saved to ~/.config/nnn/selection

Default source directory: ~/Music/charts/world"""
    messagebox.showinfo("Instructions", instructions)

if __name__ == "__main__":
    # Show instructions first
    show_instructions()
    # Then open the file dialog
    select_pdf_files()
