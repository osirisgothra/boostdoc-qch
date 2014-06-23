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


case $- in *i*) $BASH_SOURCE "$@"; return;; esac

# be nice
if [[ -z $FILES_LIST_RUNNING ]]; then
	export FILES_LIST_RUNNING=YES
	nice $BASH_SOURCE "$@"
	unset FILES_LIST_RUNNING
	exit $?
fi


[[ -r files.list && -r files-unformatted.list ]] && { echo "file lists already exist, skipping generation"; exit 0; }

echo "preparing to generate file list..."
sleep 2

[[ $1 ]] || set -- --noopt

# required bash shell options
# described in order of inclusion:
# 1 return nothing if glob matches nothing
# 2 needed for x() pattern matching verbatim 
# 3 needed for ** recursion glob

shopt -s nullglob
shopt -s globstar
shopt -s extglob

case $1 in
 --backup)
 	[[ $2 ]] || set -- $1 "/tmp"
 	echo "moving old files to $2..."
	mv files-unformatted.list "$2" -v
	mv files.list "$2" -v
	;;
 --noopt)
	echo "generating file lists, this make take a second..."
	echo "removing old (if existing)"
	rm files-unformatted.list -f
	rm files.list -f
	;;
esac

echo "generating files.list (used for insertion into qhp files)..."
find -regextype posix-egrep -iregex '.*\.(png|html|css|htm)' | sed --regexp-extended 's/^(\.\/)(.*)$/<file>\2<\/file>/g' > files.list
echo "begin [multiple steps]: generating files-unformatted.list (used for keyword collection and link-rewriting operations)..."
echo "generating unique list of directories with keyword files..."
find -type f -iregex ".*.html" -exec dirname '{}' ';' | sort | uniq > unique.list
echo "loading directories..."
mapfile ITEMS < unique.list
echo "creating list..."
echo -ne "[s"
for item in ${ITEMS[@]}; do
echo -ne "[1K[u[sprocessing ${item}..."
echo $item >> filedirs.list
find $item -maxdepth 1 -iname '*.html' >> filedirs.list
done
echo "cleaning up and writing to files-unformatted.list..."
cat filedirs.list | sed "s/^\.\///g" > files-unformatted.list
echo "done: generating files-unformatted.list"
echo "cleaning up intermediate files..."
rm unique.list -f 
rm filedirs.list -f
echo "done."

