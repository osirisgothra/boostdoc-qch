#!/bin/bash                                                                  

################### VERIFY INTERPRETER (MUST BE DONE FIRST!) ##################

echo "Checking interpreter..."
if [ -n "$BASH_SOURCE" -a "$BASH" != "/bin/sh" ]; then
	if (( BASH_VERSINFO[0] >= 4 && BASH_VERSINFO[1] >= 2 )); then
		echo "OK"
	else
		echo -e "Failed\nInterpreter Error: the bash interpreter version needs to be at least 4.2x, yours is $BASH_VERSION. Please update bash and try again!"
		return 2
	fi
else
	echo -e "Failed\nInterpreter Error: the interpreter being used to read this file is incompatible (old version or not right interpreter). Update bash and try again!"
	return 3
fi

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
declare -g TTY=$(tty)																	#needed for dbg msg

######################## FUNCTION DECLARATIONS ################################

#F verify_correct_startdir [noparams] 
function verify_correct_startdir()
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
 
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
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
 	
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
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
 
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
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
 	
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
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
 
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
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
 
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
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
	
	echo -ne "initializing global variables (this might take a minute)..."
	local -i ERRCNT=0
	local -i IGVACT
	case $# in 
		0) IGV_ACT=_dodeclare;;
		*) IGV_ACT=_dounset;;
	esac	
	declare -Ag HTML_SYMBOLS																																; ((ERRCNT+=$?))
	declare -ig RETV=1 																																			; ((ERRCNT+=$?))
	declare -ig FALLBACK_SCREEN_WIDTH=80                                                    ; ((ERRCNT+=$?))
	declare -ig FALLBACK_SCREEN_HEIGHT=25                                                   ; ((ERRCNT+=$?))
	declare -g INITDIR=$PWD                                                                 ; ((ERRCNT+=$?)) 
	declare -ig INDENTS=-1                                                                  ; ((ERRCNT+=$?)) 
	declare -ig MAXTITLELEN=71                                                              ; ((ERRCNT+=$?)) 
	declare -ig TOTALCOUNT=0                                                                ; ((ERRCNT+=$?))   
	declare -ig INDEXCOUNT=$(find -L -type f -iname 'index.htm*' | grep -s '.*' --count)    ; ((ERRCNT+=$?)) 
	declare -ig DIRCOUNT=$(find -L -type d | grep -Ps ".*(?<=\/\.).*" -v --count)           ; ((ERRCNT+=$?)) 
	declare -ig HTMLCOUNT=$(find -L -type f -iname '*.htm*' | grep -s '.*' --count)         ; ((ERRCNT+=$?)) 
	declare -ig FINALCOUNT=$(( HTMLCOUNT - INDEXCOUNT + DIRCOUNT ))                         ; ((ERRCNT+=$?))
	declare -igx COLUMNS=0 LINES=0																													; ((ERRCNT+=$?))
	declare -ga ARGVS                                                                       ; ((ERRCNT+=$?))
	echo "Done"
	return $ERRCNT
}

#F calc_file_dir_sizes [no params]
function calc_file_dir_sizes()
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
 
	echo "calculating file and directory counts..."
	eval "$(resize | sed 's/^/declare -ix /g' | grep -s "declare -ix (COLUMNS|LINES)\=[0-9]+;" --line-regexp -Po)"
	if [[ $COLUMNS == 0 || $LINES == 0 ]]; then
		echo "Warning: can't determine terminal size, guessing standard ${FALLBACK_SCREEN_WIDTH}x${FALLBACK_SCREEN_HEIGHT} screen"
		COLUMNS=${FALLBACK_SCREEN_WIDTH}
		LINES=${FALLBACK_SCREEN_HEIGHT}
	fi
}


#F get_meta_refresh_target [filename]
function get_meta_refresh_target()
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
	local BASEDIR=$(dirname $1) # dont use PWD because we might be looking elsewhere (gbi)
	local LTGT=$(cat $1 | grep -Pos "<meta *.*http-equiv=\"?refresh\"?.*>" 2>/dev/null  | grep -Pos "(?<=URL\=)[^\"]*" ) # see .smell gmrt#1
	if [[ ${LTGT,,} =~ http://.* ]]; then
		echo "$LTGT"
	else	
		local MFTGT=${BASEDIR#$INITDIR/}/$LTGT #(readlink -e $LTGT) removed due to autoimport's linking traversing back to origin dirs
		if [[ $? -eq 0 ]]; then
			echo $MFTGT
		else
			echo INVALID
			return 1
		fi
	fi
}

#F is_meta_refresh [filename]
function is_meta_refresh()
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
 	
	grep -sq "<meta.*refresh.*URL=.*>" ${1}
	return $?
}

#F get_index_file [no params]
function get_index_file()
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
 
	local ITEM="" HTMLS DIRS IDX IDXT
	IDX=$(get_nearest_index_or_html)
	if [[ -r $INITDIR/$IDX ]]; then
		if is_meta_refresh $INITDIR/$IDX; then			# index passed is also a meta-refresher
			IDXT=$(get_meta_refresh_target $INITDIR/$IDX)
			if [[ $IDXT =~ http.* ]]; then						# webpage, no verification done			
				echo "$IDXT"
			elif [[ -r ${INITDIR}/${IDXT} ]]; then
				echo "${IDXT}"
			else
				_err "Can't locate an index for $PWD: IDX=$IDX IDXT=$IDXT" p e						
				return 1
			fi
		else
			echo $IDX												# index is normal HTML
			return 0
		fi
	else
		[[ -v GENSEC_SH_INDEX_WARNINGS ]] && _err "No index in or below $PWD ($IDX)" n w
		return 1													# a competent index was not found anywhere
  fi
	return 0
}

#F load_html_symbols [noparams]
function load_html_symbols()
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY

	local SYMBOL HSYMBOL XSYMBOL SYMBOLSRCT
	SYMBOLSRCT=$(tempfile)
	local -i TSYMBOLS=0
	if [[ -r symbols.rc ]]; then
		echo "Loading html symbols..."
		cat symbols.rc | grep "^\s*//.*" -sv | grep "\&\S*\; \&\S*;" -os > $SYMBOLSRCT
		mapfile SYMBOLSRC < $SYMBOLSRCT
		for SYMBOL in "${SYMBOLSRC[@]}"; do
			#echo "S=$SYMBOL"
			HSYMBOL="${SYMBOL% *}"
			#echo "H=$HSYMBOL"
			XSYMBOL="${SYMBOL#* }"
			#echo "X=$XSYMBOL"
			HTML_SYMBOLS+=(["$HSYMBOL"]="$XSYMBOL") 
			#echo "O=${HTML_SYMBOLS[@]}"
			((TSYMBOLS++))
		done
		echo "$TSYMBOLS symbols loaded into entity map."
		return 0
	else
		_err "Can't load entity map from symbols.rc!!" p c
		return 1
	fi
}

#F cook_title_string ["title string"]
function cook_title_string()
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
 
	if [[ $# -ne 1 ]]; then
		_err "$FUNCNAME: title required, none given!" p e
		return 1
	else
		# benchmark: less than .001ms penalty for disabling globs on the next line
		set -f 
		local COOKSTRING=$("$INITDIR/getent.pl" "$1") # see .smell cts#1
		set +f		
		set -- "$COOKSTRING"
		if [[ $1 =~ .*\&[a-z]*\;.* ]]; then    
			for symbol in "${!HTML_SYMBOLS[@]}"; do
				if [[ $1 =~ .*${symbol}.* ]]; then
					local newitem=`echo "$1" | replace "${symbol}" "${HTML_SYMBOLS[$symbol]: 0:-1}"`
					set -- "$newitem"
				fi
			done			
		fi
    echo "${1}"
		return 0
	fi
}

#F html_title [filename]
function html_title()
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
 
	local FILELEN TITLE_RAW TITLE_POACHED="" TITLE_COOKED="" DEFAULT_TITLE
	FILELEN=`stat "$1" --format="%s" 2>/dev/null`
	TITLE_PROPER=""                                         
	if [[ $FILELEN -gt 0 ]]; then
		TITLE_RAW=$(grep -Pois '(?<=\<title\>)[^\<]*(?=\<\/title\>)' "$1") 
		if [[ -n $TITLE_RAW ]]; then
			TITLE_COOKED="$(cook_title_string "$TITLE_RAW")"
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
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY

	ARGVS=("$@")
	local TYPE=${1}; shift
	local SUFF=""
	local OUT_REF=""
	local OUT_LIST=""
	local OUT_TITLE=""
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
			OUT_REF=${3#/}
			;;&
		OPEN)
			OUT_REF=${3#/}
			;;&
		OPEN*)
			((TOTALCOUNT++))			
			#OUT_TITLE=${2} 
			# experimental: moving title resolution to be used by ref not by finder
			OUT_TITLE="$(html_title ${INITDIR}/${OUT_REF})"
			if [[ -z $OUT_TITLE ]]; then
				OUT_TITLE="$(basename $OUT_REF)"
			fi			
			#= "$(echo ${2} | sed "s/'/\&#39;/g;s/\"/\&#34;/g")" removed for original cooking above
			echo "${PREF}${1}<section title='${OUT_TITLE}' ref='${OUT_REF}'${SUFF}>" >> ${OUT_LIST}
			;;
	esac
}

# process_dir [start dir]
function process_dir()
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
 	
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
  ot_title="placeholder"
	ot_ref="$(get_index_file)"
	skip_section=$?
 #ot_title=$(html_title "$INITDIR/$ot_ref")
	

	if [[ $skip_section == 0 ]]; then
		echo_section OPEN "${INDENTER}" "$ot_title" "$ot_ref"	
		for ITEM in !(index).html !(index).htm; do
		 #ot_title=$(html_title $ITEM)
			if [[ $PWD == $INITDIR ]]; then
				ot_ref="${ITEM}"
			else
				ot_ref="${PWD#$INITDIR}/${ITEM}"
			fi
			if is_meta_refresh "$ot_ref"; then
				ot_ref=$(get_meta_refresh_target "$ot_ref")
				if [[ "$ot_ref" =~ .*"index.htm"l? ]]; then
					((TOTALCOUNT++))
					continue
				fi				
			fi	
			echo_section OPENCLOSE "${INDENTER}" "$ot_title" "$ot_ref"
	  done
	
		for DIR in */; do
			process_dir "${DIR}"
		done
		echo_section CLOSE "${INDENTER}"
	else
		# nothing under here, but the dirs were still in the final counts (prefiltering IS slower)
		((TOTALCOUNT+=$(find -type d | grep -s --count ".*" --line-regexp)))
  fi
	((INDENTS--))	&& cd .. 	
	return 0
}

#F insert_line [after line number (int)] [textdata]
function insert_line()
{
	local -i LINENUM
	head -n
}

#F polish_list [no params]
function polish_list()
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
 
	echo "applying polish..."
	#TODO: replace ref="." section with a nice title
	#TODO: replace root ref and title with our own page (so we can get some credit)
	#TODO: remove un-needed intermediate tags (see below)
}

#F verify_validate [no params]
function verify_validate()
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
 

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
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
 
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
{	[[ -v GENSEC_SH_DFA ]] && echo "[1m$FUNCNAME: 0=$0 #=$# @=$@[0m" > $TTY
 
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
		if [[ ! -v GENSEC_RELOAD ]]; then
			echo "** interactive run detected **"
			echo "Do you want to load script for debugging?"
			echo "Note: This WILL overwrite your current shell!"
			echo "Proceed ([y]/n):"			
			if _choice yn 0; then
				GENSEC_RELOAD=1										
			fi
		fi
		# added to suppress messages for subsequent reloads
		if [[ -v GENSEC_RELOAD ]]; then
			init_global_vars
			calc_file_dir_sizes		
			echo "debug function mode:"
			echo " - You will need to restart the shell if you want to unload it"
			echo " - Type [rls] to reload the script"
			echo " - type [sls] for a function list from this script"
			echo " - use [ton] and [toff] to enable/disble trace"
			echo " - because of shell options, autocomplete on multiple words won't function,"
			echo "   enabling that would break functions!"
			alias rls="GENSEC_RELOAD=1; pushd .; cd $PWD; source $BASH_SOURCE; popd"
			alias sls="pushd .; cd $PWD; cat $BASH_SOURCE | grep -Pos '(?<=^#F ).*' | sort | uniq; popd"
			alias ton='set -x'
			alias toff='set +x'
		else
			echo "aborted"
		fi
	else
		echo "processing directories, please wait..."
		if check_script_deps; then
			if init_global_vars; then
				if calc_file_dir_sizes; then
					if load_html_symbols; then
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
		fi
		exit 1	
	fi
fi

