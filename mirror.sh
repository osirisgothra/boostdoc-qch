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
# Note: this is not to be used as a repo branch replacement, it is meant to
#       serve as a test location that can be completely destoryed even the
#       base directory itself can be. No changes are saved from it, either
#       so DO NOT USE MIRROR DIRECTORIES FOR EDITING SCRIPTS! Use git for
#       branching experimental changes. In contrast, if the entire project
#       directory were corrupted/destroyed/deleted, there would be no going
#       back except for the copy on gitorious assuming everything was pushed
#       at the time. Instead the mirror directory is used for testing scripts
#       to ensure they do not do just that. And if they do, no harm is done.
#
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

echo -ne "acquiring new mirror directory..."
TARGET=$(readlink -f $(mktemp -du ../$(basename $PWD)-mirror-XXX))
if mkdir -p $TARGET; then
	echo "$TARGET"
	echo "calculating..."
	ITEMS=($(find | grep ".*\.git.*" --line-regexp --invert-match | sed "s/^\.\///g"))	 
	TOTAL=${#ITEMS[@]}
	echo "starting operation..."
	for ((i=1;i<TOTAL;i++)); do
		PERCENT=$(( (i*100)/TOTAL ))
		echo "[2K[scopying files... (${PERCENT}% complete)[u"
		NEXTITEM=${ITEMS[i]}
		if [[ -d $NEXTITEM ]]; then
			mkdir -p $NEXTITEM $TARGET/$NEXTITEM
		else
			cp --no-clobber $NEXTITEM $TARGET/$NEXTITEM
		fi
	done
	echo "\nfinished... moving you there..."
	cd $TARGET
	echo
	echo "MIRROR CREATED SUCCESSFULLY"
	echo "YOU ARE NOW IN: $TARGET"
	head $BASH_SOURCE -n35 | tail -n+10 | tr -d '#'
	exit $?
else
	echo "*** FAILED! did not make a mirror, please make sure you can create directories (and write files) in $(basename $PWD)"
	exit 1
fi
