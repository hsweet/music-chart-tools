# PDF File Selector - Future Improvements

## My Priority
- [ ] Ensure the Done button works even when the file dialog is open
- [hard] Keep focus on the file dialog box while using
- [ ] Keybinding (l) to view pdf file with external viewer  
- [ ] Program always returns to the original directory even after switching to a new one as soon as a file is picked 
- [ ] Intergrate with select.py. Maybe just a return statement in the finish_selection function.  Or change the output file path to .config/nnn/selection 
- [ ] Allow reordering of selected files
- [ ] Add a button to show help text (instructions) rather than show every time the program is run
- [ ] Remove Selected not working, fix
- [ ] Make the file dialog larger and more user-friendly
- [ ] Add Selection for commonly used folders (e.g., ~/Music/charts/world, charts/lyrics, etc)
- [ ] Add a counter showing the number of selected files

## High Priority
- [ ] Add support for selecting multiple files at once
- [ ] Improve error handling for invalid PDF files

## Medium Priority
- [ ] Remember the last used directory between sessions
- [ ] Add a search/filter box for the file dialog
- [ ] Improve window management between main window and file dialog

## Low Priority
- [ ] Add keyboard shortcuts (e.g., Enter to add, Delete to remove, Esc to close)
- [ ] Add a preview pane for selected PDFs
- [ ] Add file size and modification date in the list
- [ ] Add support for different file sorting options

## Completed
- [x] Created basic file selection interface
- [x] Added ability to maintain selection order
- [x] Added file list display
- [x] Added instructions dialog
- [x] Save selected files to a text file

## Notes
f this doesn't work, we could consider creating a custom file dialog using ttk widgets, which would give us full control over the focus behavior. Would you like me to show you how to implement that approach instead?