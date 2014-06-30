#!/bin/bash
#
# mirror.sh
#
# (C)2014 Gabriel Sharp, Paradisim LLC, All Rights Reserved
#
# utility for experimental phase  
# copies entire branch into a temporary location
# (three-letter temp signia allows for ~ 16 million unique entries)
# 
# Note: This directory is not to be used as a branch replacement, it is meant to
#       serve as a test location that can be completely destoryed. It can even 
#       have it's base destroyed as well. No changes will be saved from it
#       unless [s]ymlinks are chosen. Without symlinks, DO NOT USE MIRROR 
#       DIRECTORIES AND THEN EDIT SCRIPTS! Please use git for the purpose of
#       branching experimental changes. Case in point: if the entire project
#       directory were corrupted/destroyed/deleted, there would be no going
#       back except for the copy on gitorious assuming everything was pushed
#       at the time. Instead the mirror directory is used for testing scripts
#       to ensure they do not do just that. And if they do, no harm is done.
# Guidelines
#
#     - Please delete mirror directories when done.
#     - Mirrors are placed in ../dir, so dont keep the project in a bottom
#       level directory (ie, /boostdoc-qch), instead use a nth-level directory
#       where the parent is yours (ie, /home/you/projects/boostdoc-qch), in
#       which case mirror would be in /home/you/projects/<mirror dir name>
#       and is alot more sane.
#     - Don't do disasterous things on the original project directory: the 
#       reason this script exists is to ensure continued stability of the
#       project and prevent accidental git branch corruption from happening.
#       [by corruption, i mean file placement, size, and existance, not actual
#        corruption of the /.git directory which is unlikely. More likely is
#        the accidental deletion of files or the /.git directory!]
# 
# This file is licensed in accord with the rest of the project, see LICENSE
# which is included in the project's directory.

# size, in MB, to ensure is going to be free AFTER copy, you should only change this 
# if you need more, it is not recommended to REDUCE this number!!
# if in vim, you can just put the cursor over the number, and press CTRL+A to increment it
# or CTRL+X to decrement it, negative numbers will cause bad things to happen, dont do it!
RUNOUT_PADDING=10
SIZE1=$(du --max-depth=0 . --total | grep -Po "^[0-9]*(?=\ttotal\$)")
SIZE2=$(df . | grep Filesystem -v | awk '{ print $4 }')
# note: we are comparing 1K blocks, not bytes, so only need to x1024 one time
SIZE3=$(( $SIZE2 - (1024*$RUNOUT_PADDING) ))
if [[ $SIZE3 -lt $SIZE1 ]]; then
	echo "fatal: you are short $[SIZE1-SIZE2] bytes for the copy, free up some space first!"
	echo "note that you need to have $SIZE1 plus ${RUNOUT_PADDING}mb free (to avoid runouts from other apps"
	exit 1
fi
        
if [[ ! -r ~/.config/boostdoc-qch/mirror-neverask ]]; then
	echo "Time (and possibly resource) Consuming Process"
	echo "----------------------------------------------"
	echo "This tool makes a mirror copy of the boostdoc directory, and starts a" 
	echo "new shell in that directory. It also cleans up (unless directed othe-"
	echo "rwise)  the directory after exiting the shell.  Since copy operations"
	echo "can be very lengthy,  you are being asked if you wish to proceed now."
	echo
	echo "Space left on drive before: $((SIZE2/1024))MB (on THIS device, not others) "
	echo "                     after: $(((SIZE2 - SIZE1)/1024))MB (nonsymetrical)"
	echo "                difference: $((SIZE1/1024))MB (size of tree)"
	echo -ne "Proceed? (Y=Yes N=No A=Always(Never Ask Me Again!!):"
	unset REPLY
	until [[ ${REPLY^^} =~ [YNA] ]]; do
		read -sn1
	done
	case ${REPLY^^} in
		A)
			mkdir ~/.config/boostdoc-qch -p
			touch ~/.config/boostdoc-qch/mirror-neverask
			echo "NeverAskAgain"
			;;
		N)
			echo "No-Abort"
			exit 1
			;;
		Y)
			echo "Yes-Proceed"
			;;
	esac
fi

echo "checking current directory..."
if [[ -r boostdoc-qch-doc.uuid ]] && [[ $(cat boostdoc-qch-doc.uuid) == "e86d1bcf-fcb1-414c-98d0-97eea12d5927" ]]; then
	echo "verified, checking for mirror signature..."
	if [[ -r .mirrorcopy ]]; then
		echo "error: this is a mirror copy, you must run mirror.sh on the original source directory!"
		echo "(if you are in mirror mode now, please type [1mexit[0m to return to normal."
		exit 1
	else
		echo "no signature found, this IS the original source directory..."
	fi
else
	echo "ERROR: source directory signature not found (uuid), this is NOT the (complete) source tree, please run mirror.sh from there"
	exit 1
fi

echo -ne "acquiring new mirror directory..."
TARGET=$(readlink -f $(mktemp -du ../$(basename $PWD)-mirror-XXX))
if mkdir -p $TARGET; then
	echo "$TARGET"
	echo "calculating..."
	ITEMS=($(find | grep ".*\.git.*" --line-regexp --invert-match | sed "s/^\.\///g"))	 
	TOTAL=${#ITEMS[@]}
	echo "starting operation..."
	echo -ne "[s"
	for ((i=1;i<TOTAL;i++)); do
		PERCENT=$(( (i*100)/TOTAL ))
		echo -ne "[2K[scopying files... (${PERCENT}% complete)[u"
		NEXTITEM=${ITEMS[i]}
		if [[ -d $NEXTITEM ]]; then
			mkdir -p $NEXTITEM $TARGET/$NEXTITEM
		else
			cp --no-clobber $NEXTITEM $TARGET/$NEXTITEM
		fi
	done
	echo "marking directory..."
	if touch $TARGET/.mirrorcopy; then
		echo "mirrored directory marked (to prevent remirroring of the mirror)"
	else
		echo "could not write to mirror (maybe out of disk space), deleting $TARGET/mirror.sh as an alternative.."
		if rm $TARGET/mirror.sh; then
			echo "mirror deleted ok, check your free space immidiately."
		else
			echo "can't even delete the file, this probably means you have no access permissions to these files..."
			echo "(will try to proceed anyway, to abort hit CTRL+C)"
			sleep 2
		fi
	fi
	if [[ ${1^^} =~ [RSWP] ]]; then
	   echo "operation selected on command line (${1^^}), honoring it..."
	else
		echo "Operation Mode"
		echo "/-----------------------------------------------------------------------\\"
		echo " | R - Readonly - Scripts will be write-protected (no changes allowed)  |"
		echo " | S - Symlink  - Scripts will be linked to originals (preserve changes)|"
		echo " | W - Writable - No write protection, but changes won't be saved       |"
		echo " | P - Preserve - Nothing, don't delete the mirror when you type 'exit' |"
		echo " | hint: you can specify this letter on the command line to save time   |"
		echo "\\-----------------------------------------------------------------------/"
		echo -ne "Select (R,S,W or P):"
		unset PRESERVE	  
	fi

	while : ; do
		if [[ ${1} =~ [RSWPrswp] ]]; then
			CHOICE=${1^^}
		else
			CHOICE=$(read -sn1; echo ${REPLY^^})
		fi
		case ${CHOICE} in
			S) 
				echo "making symlinks..."
				for i in *.sh *.pl; do
					rm $TARGET/$i
					ln -s $PWD/$i $TARGET/$i
				done
				break;;
			W)
				echo "keeping writable filesystem..."
				break;;
			P)
				echo "setting preserve flag..."
				PRESERVE=YES
				break;;
			R)			
				echo "setting permissions..."
				chmod a-w $TARGET/*.sh $TARGET/*.pl
				break;;				
		esac

	done

	echo "finished... "	
	echo
	echo "MIRROR CREATED SUCCESSFULLY"
	echo "YOUR NEW MIRROR IN: $TARGET"
	head $BASH_SOURCE -n35 | tail -n+10 | tr -d '#'
	
	cd "$TARGET"
	echo "Changed to $PWD"
	
	echo "[1mType [32mexit[0;1m to return to the previous shell[1;30m![0m"
	bash
	if [[ -z $PRESERVE ]]; then
		echo "cleaning up mirror..."
		echo "press ENTER to delete $TARGET or CTRL+C if you changed your mind"
		read -s
		rm -fr $TARGET
	else
		echo "preserving mirror (as per requested mode)"
	fi
	echo "returning you to your former shell..."			
else
	echo "*** FAILED! did not make a mirror, please make sure you can create directories (and write files) in $(basename $PWD)"
	exit 1
fi
