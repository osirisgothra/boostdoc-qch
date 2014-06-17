#!/bin/bash
#
# generatesections.sh
#
# make the sections.list for the qhp generator
# you will need to run:
# 		./generatefiles.sh
# before using this script, it requires files-unformatted.list in order to generate the list
#
# warning: the original list will be deleted without mercy
#

echo "generating sections, this make take a second..."
echo "removing old (if existing)"
rm sections.list -f
echo "generating sections.list (used for insertion into qhp files)..."
# TODO: do the generation
# for now i only create the file itself so it is not missed in the generation of the project
# ------------------------------------------------------------------------------------------
touch sections.list
# ------------------------------------------------------------------------------------------
echo "done."

