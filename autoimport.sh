#!/bin/bash
# autoimport.sh
# imports your bash docs

unset FOUNDDOC
function exec_autoimport()
{
	TARGET=${1}
	# since we are doing some potentially dangerous stuff like moving directories around
	# we must be tripple-sure we are in the right directory before starting 
	# file names aren't enough, this is why the project includes a uuid file 
	echo "verifying project directory..."
	UUIDFILE=$(cat boostdoc-qch-doc.uuid)
	if [[ "$UUIDFILE" == "e86d1bcf-fcb1-414c-98d0-97eea12d5927" ]]; then
		echo "verified, checking state of project directory..."
		if [[ -r .imported ]] || [[ -d .originals ]]; then
			echo "*** ERROR: you have already imported a help documentation, please use the --undo parameter to remove it first!"
		else
			echo "creating data..."
			touch .imported
			mkdir .originals
			echo "backing up project's original documentation skeleton..."
			for ITEM in $(cat autoimport.ini); do
				mv $ITEM .originals
			done
			echo "importing boost documentation from ${1}..."
			for ITEM in $TARGET
				ln -s $ITEM .
				echo "$ITEM" >> .imported
			fi
		fi
	else
		echo "*** ERROR: you must run this script from the project directory, UUID mismatch: ${UUIDFILE-uuid file not found}!"
		echo "           if you think this is a bug please contact the author (see README)"
	fi
}
function locate_docs()
{
	echo "searching $1 ..."
	if [[ -r ${1}/HTML/index.html ]]; then
		FOUNDDOC=$1
		return 0
	fi
	return 1
}

echo "checking for dpkg..."
if type -fp dpkg; then
	echo -ne "found dpkg, searching for your boost docs install..."
  FOUNDDOC=$(dpkg -L libboost-doc | grep ".*libboost-doc" --line-regexp)
 	if [[ -z $FOUNDDOC ]]; then
		echo "package not installed"
	else
		echo "package found"
	fi
fi
if [[ -z $FOUNDDOC ]]; then
	echo "looking for packages (without package manager)..."
	# add any more dirs you think might be worthwhile here, or in an array of BOOST_DOC_ROOT
	for LOCATION in ${BOOST_DOC_ROOT[@]} /usr/share/doc/libboost-doc /usr/local/share/doc/libboost-doc /opt/libboost-doc ~/.local/share/doc/libboost-doc; do
		if locate_docs $LOCATION; then
			break
		fi
	done
	if [[ -z $FOUNDDOC ]]; then
		echo "specific search turned up nothing, searching entire system (make take some time)..."
		FOUNDDOC=$(locate *libboost-doc -l1)
	fi
fi

if [[ -r $FOUNDDOC/HTML/index.html ]]; then
	echo "*** Found boost documentation in: $FOUNDDOC"
	exec_autoimport $FOUNDDOC/HTML
else
	echo "*** Can't find any documentation, please set BOOST_DOC_ROOT to your documentation's root (ie, /usr/share/doc/libboost-doc) and try again."
	exit 1
fi	

 


		


