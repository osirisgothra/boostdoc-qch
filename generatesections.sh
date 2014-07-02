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

declare -g PRESS_A_KEY="Press any key to continue..." #needed for _err											

######################## FUNCTION DECLARATIONS ################################

#F verify_correct_startdir [noparams] 
function verify_correct_startdir()
{
	if [[ -r boostdoc-qch-doc.uuid ]]; then
		if [[ $(cat boostdoc-qch-doc.uuid) == "e86d1bcf-fcb1-414c-98d0-97eea12d5927" ]]; then
			return 0
		fi
	fi
	_err "generatesections.sh must be started in the root project directory (where boostdoc-qch-doc.uuid is)" p c
	return 1	
}

#F check_for_existing_sections_list [no params]
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

#F get_nearest_index_or_html [no params] | internally: [start dir]
function get_nearest_index_or_html()
{
	local FILENAME
	[[ $# > 0 ]] && local -i LEVEL=$[ $1 + 1 ] || local -i LEVEL=0
	local FILES=(@(index).html @(index).htm !(index).htm?(l))
	if [[ ${#FILES[@]} -eq 0 ]]; then
		for SUBDIR in */; do
			cd "${SUBDIR}"
			if $FUNCNAME $LEVEL; then         
				cd ..
				return 0
			fi
			cd ..
		done
	else
		FILENAME=${PWD}/${FILES}
		echo "${FILENAME#${INITDIR}/}"  # == 'dirname $FILES[0]'
		return 0
 	fi
 	if [[ $LEVEL == 0 ]]; then
		echo "NONE"
	fi
	return 1
}

#F check_dep [package name]
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

#F check_script_deps [no params]
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

#F init_list [no params]
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

#F init_global_vars [no params]
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
	declare -ga ARGVS                                                                       ; ((ERRCNT+=$?))
	return $ERRCNT
}

#F calc_file_dir_sizes [no params]
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


#F get_meta_refresh_target [filename]
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

#F is_meta_refresh [filename]
function is_meta_refresh()
{	
	grep -q "<meta.*refresh.*URL=.*>" ${1}
	return $?
}

#F get_best_index [no params]
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

#F get_index_file [no params]
function get_index_file()
{
	local ITEM="" HTMLS DIRS IDX IDXT
	IDX=$(get_nearest_index_or_html)
	if [[ -r $INITDIR/$IDX ]]; then
		if is_meta_refresh $INITDIR/$IDX; then			# index passed is also a meta-refresher
			IDXT=$(get_meta_refresh_target $INITDIR/$IDX)
			if [[ -r $IDXT ]]; then
				echo "${IDXT#$INITDIR/}"
			else
				_err "Can't locate an index for $PWD!!" p e						
				return 1
			fi
		else
			echo $IDX												# index is normal HTML
			return 0
		fi
	else
		_err "No Index in or below $PWD" n w
		return 1													# a competent index was not found anywhere
  fi	
}

#F html_title [filename]
function html_title()
{
	local FILELEN TITLE_RAW TITLE_COOKED="" DEFAULT_TITLE
	FILELEN=`stat "$1" --format="%s" 2>/dev/null`
	TITLE_PROPER=""                                         
	if [[ $FILELEN -gt 0 ]]; then
		TITLE_RAW=$(grep -Poi '(?<=\<title\>)[^\<]*(?=\<\/title\>)' "$1") 
#   perl implementation, waiting until rest of script is converted to perl		
#	  TITLE_RAW=$($INITDIR/getelement.pl "$1" TITLE)		
		if [[ -n $TITLE_RAW ]]; then
			TITLE_COOKED="${TITLE_RAW//[^-.;:,_&?A-Za-z0-9# ]}"
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

#F echo_section [CLOSE|OPENCLOSE|OPEN] [indents] [title] [subdirectoryname|filename]
function echo_section()
{	
	ARGVS=("$@")
	local OUT_REF=""
	local TYPE=${1}; shift
	local SUFF=""
	local OUT_LIST=""
	local PREF=""
	local -i PERCENTAGE=$(( (TOTALCOUNT * 100) / (FINALCOUNT) ))
	case $- in *i*) OUT_LIST=/dev/stdout;;
							 *)	OUT_LIST=${INITDIR}/sections.list
						      echo ${DBGMODE--n} "[2K[sprocessing $PWD .. ${PERCENTAGE}% done[u" ;;	
	esac

	case $TYPE in
		CLOSE)	
			echo "${1}</section>" >> ${OUT_LIST}
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
			# verify and write
			if [[ ${OUT_REF: 1:1} == "/" ]]; then				
				echo "Command Line: 1=[$1] 2=[$2] 3=[$3] "
				echo "Command Line(unfiltered): *=[$*] @=[$@] #=[$#]"
			fi
			if [[ ! -f "$OUT_REF" ]]; then
				echo "Command Line: 1=[$1] 2=[$2] 3=[$3] "
				echo "Command Line(unfiltered): *=[$*] @=[$@] #=[$#]"
				_err "Item: $OUT_REF does not refer to a file, all entries MUST point to a file!!" p c
			fi
			echo "${PREF}${1}<section title=\"${2}\" ref=\"${OUT_REF}\"${SUFF}>" >> ${OUT_LIST}
			;;
	esac
}

# process_dir [start dir]
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

	ot_ref="$(get_index_file)"
	skip_section=$?
	ot_title=$(html_title "$INITDIR/$ot_ref")
	

	if [[ $skip_section == 0 ]]; then
		echo_section OPEN "${INDENTER}" "$ot_title" "$ot_ref"	
 # 	echo "LEVEL: $INDENTS  PWD: $PWD"
 # 	echo "REF: $ot_ref     TITLE=$ot_title"
		for ITEM in !(index).html !(index).htm; do
			ot_title=$(html_title $ITEM)
			ot_ref=${ITEM}
			echo_section OPENCLOSE "${INDENTER}" "$ot_title" "$ot_ref"
	  done
	
		for DIR in */; do
			process_dir "${DIR}"
		done
		echo_section CLOSE "${INDENTER}"
	else
		# nothing under here, but the dirs were still in the final counts (prefiltering IS slower)
		((TOTALCOUNT+=$(find -type d | grep --count ".*" --line-regexp)))
  fi
	((INDENTS--))	&& cd .. 	
	return 0
}

#F polish_list [no params]
function polish_list()
{
	echo "applying polish..."
	#TODO: replace ref="." section with a nice title
	#TODO: replace root ref and title with our own page (so we can get some credit)
	#TODO: remove un-needed intermediate tags (see below)
}

#F verify_validate [no params]
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

# _err [text] [pause=p|nopause=n] [kind=e[rr]|w[arn]|c[rit]|i[nf]|custom_name] 
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
	echo "** $ERRKIND (@ $PWD): $1" > $(tty)
	if [[ $# -ge 2 ]] && [[ $2 == "p" ]]; then 
		echo $PRESS_A_KEY > $(tty)
	  unset REPLY
		read -sn1	
		if [[ ${REPLY^^} == N ]]; then
			return 1
		fi		
	fi
}

# _choice [keys(default=yn)] [default-index-when-enter(default=-1, none)] 
function _choice()
{
	[[ $# == 0 ]] && set -- yn -1
	[[ $# == 2 ]] && local -i DEFAULT=$2 || local -i DEFAULT=-1
	local RESPONSE="" KEYS=${1} NEXTCHAR=""
	setterm -c off
	while (true); do
		read -sn1 RESPONSE
		if [[ $RESPONSE ]]; then
			for ((i=0;i<${#KEYS};i++)); do
				NEXTCHAR=${KEYS: $i:1}
				if [[ ${NEXTCHAR^^} == ${RESPONSE^^} ]]; then
					setterm -c on
					return $i
				fi
			done
		else
			if [[ $DEFAULT -ge 0 ]]; then
				setterm -c on
				return $DEFAULT
			fi
		fi
		RESPONSE=""		
	done
}
	


############################################### MAIN PROGRAM ##########################################################

if verify_correct_startdir; then
	if [[ ${-//[^i]} ]]; then      #interactive mode
		echo "** interactive run detected **"
		echo "Do you want to load script for debugging?"
		echo "Note: This WILL overwrite your current shell!"
		echo "Proceed ([y]/n):"
		if _choice yn 0; then
			init_global_vars
			calc_file_dir_sizes		
			echo "debug function mode:"
			echo " - You will need to restart the shell if you want to unload it"
			echo " - Type [reload] to reload the script"
			echo " - type [list] for a function list from this script"
			echo " - use [trcon] and [trcoff] to enable/disble trace"
			echo " - because of shell options, autocomplete on multiple words won't function,"
			echo "   enabling that would break functions!"
			alias reload="pushd .; cd $PWD; source $BASH_SOURCE; popd"
			alias list="pushd .; cd $PWD; cat $BASH_SOURCE | grep -Po '(?<=^#F ).*' | sort | uniq; popd"
			alias trcon='set -x'
			alias trcoff='set +x'
		else
			echo "aborted (this does not undo any previous loads)"
		fi
	else
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
						fi
					fi
				fi
			fi
		fi
		exit 1	
	fi
fi
