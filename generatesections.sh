#!/bin/bash                                                                  

####################### SHELL SETTINGS ########################################

shopt -s interactive_comments 
shopt -s extglob 																	# req'd for the @(..) glob  
shopt -s nullglob 																# nomatch globs == <null>   
shopt -s globstar 															  # for the ** globspec/deep  
shopt -s xpg_echo 																# needed for \ sequences    
shopt -o -s nounset																# strict variable declaring 
shopt -o -${XTRACE-u} xtrace	            				# easier trace variable     
shopt -o -u histexpand			 											# i REALLY hate this feature!
shopt -s checkwinsize                             # for COLUMNS and LINES

######################## FUNCTION DECLARATIONS ################################

function check_for_existing_sections_list()
{
	if [[ -r sections.list ]]; then
		echo -ne "sections.list exists, overwrite? ([y]/n)"
		if [[ $(read; echo ${REPLY^^}) == N ]]; then
			echo "aborted."
			return 1
		fi
	fi
	return 0
}

function get_nearest_index_or_html()
{
	[[ $# > 0 ]] && local -i LEVEL=$[ $1 + 1 ] || local -i LEVEL=0
	echo "examining $PWD..."
	local FILES=(@(index).htm?(l) !(index).htm?(l))
	if [[ ${#FILES[@]} -eq 0 ]]; then
		for SUBDIR in */; do
			cd "${SUBDIR}"
			if $FUNCNAME $LEVEL; then         
				return 0
			fi
			cd ..
		done
	else
		echo "${FILES[0]#${INITDIR}/}"  # == 'dirname $FILES[0]'
		return 0
 	fi
 	if [[ $LEVEL == 0 ]]; then
		echo "NONE"
	fi
	return 1
}


function check_dep()
{	
	return 0
	if dpkg --status $1 &> /dev/null; then
		echo "$1 dependency verified ok"
		return 0
	else
		echo "$1 dependency failed: this package is not installed."
		return 1
	fi
}

function check_script_deps()
{
	echo "checking script dependencies..."
	declare -i FAILED_DEPENDS=0
	for DEPITEM in grep findutils xmlstarlet; do
		if (! check_dep $DEPITEM); then
			((FAILED_DEPENDS++))
		fi
	done
	if [[ $FAILED_DEPENDS -gt 0 ]]; then
		echo "$FAILED_DEPENDS dependency failures, script can't run"
		echo $PRESS_A_KEY	
		read
		return 1
	else
		echo "required dependencies verified."
		return 0
	fi
}


function init_list()
{
	echo "generating xml header..."
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > sections.list
	if [[ -r sections.list ]]; then
		return 0
	else
		return 1
	fi
}

function init_global_vars()
{
	local -i ERRCNT=0
	declare -ig RETV=1 																																			; ((ERRCNT+=$?))
	declare -ig FALLBACK_SCREEN_WIDTH=80                                                    ; ((ERRCNT+=$?))
	declare -ig FALLBACK_SCREEN_HEIGHT=25                                                   ; ((ERRCNT+=$?))
	declare -g INITDIR=$PWD                                                                 ; ((ERRCNT+=$?)) 
	declare -ig INDENTS=-1                                                                  ; ((ERRCNT+=$?)) 
	declare -ig MAXTITLELEN=71                                                              ; ((ERRCNT+=$?)) 
	declare -ig TOTALCOUNT=0                                                                ; ((ERRCNT+=$?))   
	declare -ig INDEXCOUNT=$(find -L -type f -iname 'index.htm*' | grep '.*' --count)       ; ((ERRCNT+=$?)) 
	declare -ig DIRCOUNT=$(find -L -type d | grep -P ".*(?<=\/\.).*" -v --count)            ; ((ERRCNT+=$?)) 
	declare -ig HTMLCOUNT=$(find -L -type f -iname '*.htm*' | grep '.*' --count)            ; ((ERRCNT+=$?)) 
	declare -ig FINALCOUNT=$(( HTMLCOUNT - INDEXCOUNT + DIRCOUNT ))                         ; ((ERRCNT+=$?)) 
	declare -igx COLUMNS=0 LINES=0																													; ((ERRCNT+=$?))
																																														return $ERRCNT
}

function calc_file_dir_sizes()
{
	echo "calculating file and directory counts..."
	eval "$(resize | sed 's/^/declare -ix /g' | grep "declare -ix (COLUMNS|LINES)\=[0-9]+;" --line-regexp -Po)"
	if [[ $COLUMNS == 0 || $LINES == 0 ]]; then
		echo "Warning: can't determine terminal size, guessing standard ${FALLBACK_SCREEN_WIDTH}x${FALLBACK_SCREEN_HEIGHT} screen"
		COLUMNS=${FALLBACK_SCREEN_WIDTH}
		LINES=${FALLBACK_SCREEN_HEIGHT}
	fi
}


function get_meta_refresh_target()
{
	local MFTGT=$(readlink -e $(cat $1 | grep -Po "<meta *.*http-equiv=\"refresh\".*>"  | grep -Po "(?<=URL\=)[^\"]*"))
	if [[ $? -eq 0 ]]; then
		echo $MFTGT
	else
		echo INVALID
		return 1
	fi
}

function is_meta_refresh()
{	
	grep -q "<meta.*refresh.*URL=.*>" ${1}
	return $?
}

function get_best_index()
{
	for IDXF in *(index.html) *(index.htm); do
		if is_meta_refresh $IDXF; then
			get_meta_refresh_target $IDXF			
		else
			echo $IDXF
		fi
		return
	done
		echo "none"
	return 1
}

function get_index_file()
{
	local ITEM="" HTMLS DIRS IDX IDXT
	IDX=$(get_nearest_index_or_html)
	if [[ -r $IDX ]]; then
		if is_meta_refresh $IDX; then			# index passed is also a meta-refresher
			IDXT=$(get_meta_refresh_target $IDX)
			if [[ -r $IDXT ]]; then
				echo "$IDXT"
			else
				echo "Can't locate an index for $PWD!!"
				echo $PRESS_A_KEY
				read
				return 1
			fi
		else
			echo $IDX												# index is normal HTML
			return 0
		fi
	else
		return 1													# a competent index was not found anywhere
  fi	
}

function html_title()
{
	local FILELEN TITLE_RAW TITLE_COOKED DEFAULT_TITLE
	FILELEN=`stat "$1" --format="%s" 2>/dev/null`
	TITLE_PROPER=""                                         
	if [[ $FILELEN -gt 0 ]]; then
	  TITLE_RAW=$($INITDIR/getelement.pl "$1" TITLE)		
		if [[ -n $TITLE_RAW ]]; then
			TITLE_COOKED=$($INITDIR/getent.pl "$TITLE_RAW")				
		fi
	fi
	if [[ -n $TITLE_COOKED ]]; then
		echo $TITLE_COOKED
	else
		if [[ $PWD != $INITDIR ]]; then
			echo ${PWD#*/}
		else
			echo "Untitled"
		fi
	fi

}

function echo_section()
{	
	local OUT_REF=""
	local TYPE=${1}; shift
	local SUFF=""
	local PREF=""
	local -i PERCENTAGE=$(( (TOTALCOUNT * 100) / (FINALCOUNT) ))
  echo ${DBGMODE--n} "[2K[sprocessing $PWD .. ${PERCENTAGE}% done[u"

	case $TYPE in
	CLOSE)	
		echo "${1}</section>" >> ${INITDIR}/sections.list
		;;
	OPENCLOSE)
		SUFF="/"
		PREF="\t"
		[[ $INITDIR == $PWD ]] && OUT_REF=${3} || OUT_REF=${PWD#$INITDIR/}/${3}		
		;;&
	OPEN)
		if [[ -f ${3} ]]; then
			OUT_REF=${PWD#$INITDIR/}/${3}
		else			
			OUT_REF=${PWD#$INITDIR}
		fi
		
		;;&
	OPEN*)
		((TOTALCOUNT++))
		echo "${PREF}${1}<section title=\"${2}\" ref=\"${OUT_REF}\"${SUFF}>" >> ${INITDIR}/sections.list
		;;
	esac
}

function process_dir()
{
	local ITEM DIR INDENTER ot_ref ot_title INDEXES kk skip_section
	((++INDENTS))
	if [[ $INDENTS -gt 0 ]]; then
		cd "$1"
	fi
	INDENTER=""
	if [[ $INDENTS -gt 0 ]]; then
		INDENTER=$(eval printf "\\\t%.0s" {1..$INDENTS})
	else
		INDENTER=""
	fi
	ot_ref=$(get_index_file)
	skip_section=$?
	ot_title=$(html_title "$ot_ref")

	if [[ $skip_section == 0 ]]; then
		echo_section OPEN "${INDENTER}" "$ot_title" "$ot_ref"	
		for ITEM in !(index).html !(index).htm; do
			ot_title=$(html_title $ITEM)
			ot_ref=${ITEM}
			echo_section OPENCLOSE "${INDENTER}" "$ot_title" "$ot_ref"
	  done
	fi	

	for DIR in */; do
		process_dir "${DIR}"
	done
	echo_section CLOSE "${INDENTER}"

	((INDENTS--))	&& cd .. 	
	return 0
}

function polish_list()
{
	echo "applying polish..."
	#TODO: replace ref="." section with a nice title
	#TODO: replace root ref and title with our own page (so we can get some credit)
	#TODO: remove un-needed intermediate tags (see below)
}

function verify_validate()
{

	[[ -r sections.list ]] && {
			echo "\nfinished, sections.list is $(stat sections.list --format='%s') bytes long"; } || {
			echo "\ndone, but sections.list not created (failed!)"; exit 1; }

	echo "Validating xml structure..."
	if xmlstarlet val -w -e sections.list; then
		echo "Validation suceeded, file is ready for insertion into qhp."	
		RETV=0 
	else
		echo "Validation failed. file not well formed, so we can't use it."
		echo "See error above for details or contact the author if you think this is a bug."
	fi

}

function _err()
{
	local ERRKIND="Error"
	if [[ $# -ge 3 ]]; then
		case $3 in
			e|err) ERRKIND="Error";;
			w|warn) ERRKIND="Warning";;
			f|fatal) ERRKIND="FATAL";;
			c|crit) ERRKIND="CRITICAL";;
			i|inf) ERRKIND="Note";;
			*) ERRKIND="$3";;
		esac
	fi
	echo "** $ERRKIND (@ $PWD): $1"
	if [[ $# -ge 2 ]] && [[ $2 == "p" ]]; then #use 'n' or something other than 'p' for no pause
		echo $PRESS_A_KEY
	  unset REPLY
		read -sn1	
		if [[ ${REPLY^^} == N ]]; then
			return 1
		fi		
	fi
}


############################################### MAIN PROGRAM ##########################################################

 

echo "processing directories, please wait..."
if check_script_deps; then
	if init_global_vars; then   # uses dependencies, check them first
	if calc_file_dir_sizes; then
	if check_for_existing_sections_list; then
	if init_list; then

	if process_dir "."; then
		if verify_validate; then
			if	polish_list; then
				exit 0
			fi
		fi
	fi
exit 1	
