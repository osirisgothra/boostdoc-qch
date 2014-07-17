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
# warning: the original lists will be deleted without (much) mercy
#

case $- in *i*) $BASH_SOURCE "$@"; return;; esac

# be nice
if [[ -z $FILES_LIST_RUNNING ]]; then
	export FILES_LIST_RUNNING=YES
	nice $BASH_SOURCE "$@"
	unset FILES_LIST_RUNNING
	exit $?
fi

[[ -r files.list && -r files-unformatted.list ]] && { 
	echo -ne "File lists exist, regenerate them (pick yes if you are going to regenerate sections)? ([Y]/n):"
	if [[ $(read -sn1; echo ${REPLY^^}) != N ]]; then
		echo "YES"
	else
		echo "NO"
		exit 0
	fi
}

echo "Preparing to generate file list..."

[[ $1 ]] || set -- --noopt

shopt -s interactive_comments
shopt -s nullglob globstar extglob

case $1 in
 --backup)
 	[[ $2 ]] || set -- $1 "/tmp"
 	echo "Moving old files to $2..."
	mv files-unformatted.list "$2" -v
	mv files.list "$2" -v
	;;
 --noopt)
	echo "Doing pre-generation checks..."
	if [[ -f files-unformatted.list ]] || [[ -f files.list ]]; then
		echo "Removing old file lists..."
		rm files-unformatted.list -f
		rm files.list -f
	fi
	;;
esac

echo "Generating QHP content list..."
find -L -regextype posix-egrep -iregex '.*\.(png|html|css|htm)' | sed --regexp-extended 's/^(\.\/)(.*)$/<file>\2<\/file>/g' > files_unpol.list
echo "polishing..."
cat files_unpol.list | grep "<file>[^\.].*" > files.list

echo "Preparing to generate RAW content list..."
echo "finding targets..."
find -L -type f -iregex ".*.html" -exec dirname '{}' ';' > raw.list
echo "sorting..."
cat raw.list | sort > sorted.list
echo "consolidating..."
cat sorted.list | uniq > unique.list
echo "removing temporary files..."
rm sorted.list raw.list

if [[ -r unique.list ]]; then
	echo "Loading directories..."
	mapfile ITEMS < unique.list
  if [[ ${#ITEMS[@]} > 0 ]]; then
		echo "Creating content directory map..."
		echo -ne "[s"
		for item in ${ITEMS[@]}; do
			echo -ne "[1K[u[sAnalyzing ${item}..."
			echo $item >> filedirs.list
			find -L $item -maxdepth 1 -iname '*.html' >> filedirs.list
		done

		echo "Filtering..."
		cat filedirs.list | sed "s/^\.\///g" > files-unformatted.list

		echo "Removing temporary files..."
		rm unique.list -f 
		rm filedirs.list -f

		echo "Generating File Lists: DONE"
	fi
fi
