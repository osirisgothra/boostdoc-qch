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

[[ $1 ]] || set -- --noopt

# required bash shell options

shopt -s nullglob
shopt -s globstar
shopt -s ext

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
echo "generating files-unformatted.list (used for keyword collection and link-rewriting operations)..."
find -regextype posix-egrep -iregex '.*' | sed --regexp-extended 's/^(\.\/)(.*)$/\2/g' > files-unformatted.list.pre
echo "polishing files-unformatted.list..."
cat files-unformatted.list.pre | grep ".*\.git.*" --invert-match > files-unformatted.list.pre2
# polish by entry start
mapfile ITEMS < files-unformatted.list.pre
touch files-unformatted.list
for item in "${ITEMS[@]}"; do
	unset ADDIT   	
	if [[ -d "$item" ]]; then
		if (ls $item/*.html | grep -P '\b\.html\b' -q); then
	 		ADDIT=TRUE
		fi	 
	else
		if [[ ${item##*.} == html ]]; then
			ADDIT=TRUE
		fi
	if [[ $ADDIT == TRUE ]]; then
    echo "$item" >> files-unformatted.list
	fi
done

# polish by entry end

echo "cleaning up intermediate files..."
rm files-unformatted.list.pre  -f 
rm files-unformatted.list.pre2 -f
echo "done."

