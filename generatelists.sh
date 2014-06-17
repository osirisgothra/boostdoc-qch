#!/bin/bash
#
# generatefiles.sh
#
# regenerates the core lists of the help files needed for the qhp file to be built upon
# the distributed ones should work fine, but if you transfer a newer version of help or
# extras over this generator, you will need to run this to get the qhp to include them
#
# syntax: ./generatefiles.sh
#
# warning: the original lists will be deleted without mercy
#

echo "generating file lists, this make take a second..."
echo "removing old (if existing)"
rm files-unformatted.list -f
rm files.list -f
echo "generating files.list (used for insertion into qhp files)..."
find -regextype posix-egrep -iregex '.*\.(png|html|css|htm)' | sed --regexp-extended 's/^(\.\/)(.*)$/<file>\2<\/file>/g' > files.list
echo "generating files-unformatted.list (used for keyword collection and link-rewriting operations)..."
find -regextype posix-egrep -iregex '.*\.(png|html|css|htm)' | sed --regexp-extended 's/^(\.\/)(.*)$/\2/g' > files-unformatted.list
echo "done."

