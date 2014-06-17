#!/bin/bash
#
#  make-boost-qhp.sh
#
#  generate the boost.qhp needed before compilation
#  you wont need to run this, instead run make
#  to only compile with the existing qhp file
#  only use this if you added files to the help index

# regenerate the file lists
./generatelists.sh

# regenerate the section lists
./generatesections.sh 

# create the output file
# the boost.qhpsrc is used to do this in the following manner:
#      1-9 [sections] 10-12 [filelist] 13-15
# numbers represent line number and are one-based (start at line 1)
# DO NOT EVER CHANGE THE SOURCE "boost.qhpsrc" OR ELSE THIS WONT WORK!!
if [[ -r boost.qhpsrc ]] && [[ -w . ]]; then
	head boost.qhpsrc -n9 > boost.qhp
	[[ -r sections.list ]] && cat sections.list >> boost.qhp || echo "Warning: no section list, output project file will contain no sections other than the index (top) section!" 
	tail boost.qhpsrc -n6 | head -n3 >> boost.qhp
	[[ -r files.list ]] && cat files.list >> boost.qhp || echo "Warning: no file list, output project file will contain no files!"
	tail boost.qhpsrc -n3 >> boost.qhp
else
	[[ ! -r boost.qhpsrc ]] && echo "Error: boost.qhpsrc not found, can't continue without it (are you in the same dir with it? permission to read?)"
	[[ ! -w . ]] && echo "Error: cannot create files in current directory, please check your permissions. This command can't generate anything without them!"
	echo "One or more errors stopped the generation."
	echo "Follow any instructions you were given or contact your system administrator."
fi
echo "Script Execution Completed."
