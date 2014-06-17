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

# get_html_title [filename]
function get_html_title()
{
	if [[ -r "$1" ]]; then
		cat "$1" | tr '\n' ' ' | grep -Po "(?<=<title>).*(?=</title>)"
		return 0
	else
		return 1
	fi
}
# returns [true] = "Title Text"  [false] = (nothing)

# get_file_section_entry [filename]
function get_file_section_entry()
{
	SECTIONTITLE=$(get_html_title "$1")
	if [[ -z $SECTIONTITLE ]]; then
		return 1
	else
		unset INDENTS
		declare -i MAXINDENTS=10
		while (true); do		
			DIRNAME=$(dirname $DIRNAME)
			if [[ $DIRNAME == $PWD ]]; then
				break
			else
				INDENTS+='\t'
				((MAXINDENTS--))
			fi
			if ((MAXINDENTS==0)); then
				break
			fi
		done
		

		echo "$INDENTS<section title=\"$SECTIONTITLE\" ref=\"$1\">"
	  return 0
	fi
}
# returns [true] = 
#   <section title="Title Text" ref="file.name">
#         [false] = (nothing)

# get_section_endtag [no arguments]
function get_section_endtag()
{
	echo "</section>"
}


echo "generating sections, this make take a second..."
echo "removing old (if existing)"
#rm sections.list -f
echo "generating sections.list (used for insertion into qhp files)..."
# TODO: do the generation
# for now i only create the file itself so it is not missed in the generation of the project
# ------------------------------------------------------------------------------------------
mapfile ITEMS < files-unformatted.list

# ------------------------------------------------------------------------------------------
echo "done."

