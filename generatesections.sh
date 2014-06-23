#!/bin/bash                                                                  
#                     TODO: remove code smells                              #
#                                                                           #
#___________________________________________________________________________#

# SAVE CURRENT DIR                                                           
pushd . &> /dev/null

#shell options: needed for this script and explanations on what they are/why 
#               they are needed (except for the first one, which is obvious! 
shopt -s interactive_comments 
shopt -s extglob 																	# req'd for the @(..) glob  
shopt -s nullglob 																# nomatch globs == <null>   
shopt -s globstar 															  # for the ** globspec/deep  
shopt -s xpg_echo 																# needed for \ sequences    
shopt -o -s nounset																# strict variable declaring 
shopt -o -${XTRACE-u} xtrace	            				# easier trace variable     
shopt -o -u histexpand			 											# i REALLY hate this feature!
shopt -s checkwinsize                             # for COLUMNS and LINES

if [[ -r sections.list ]]; then
	echo "sections.list exists, overwrite? (y/n)"
	if [[ $(read; echo ${REPLY^^}) == N ]]; then
		echo "aborted."
		exit
	fi
fi
# check for grep, ([xargs, locate, find] = in findutils), and xmlstarlet which are required
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
echo "checking script dependencies..."
declare -i FAILED_DEPENDS=0
for DEPITEM in grep findutils xmlstarlet; do
	if (! check_dep $DEPITEM); then
		((FAILED_DEPENDS++))
	fi
done
if [[ $FAILED_DEPENDS -gt 0 ]]; then
	echo "$FAILED_DEPENDS dependency failures, script can't run"
	echo "press ENTER and this script will abort"
	# gives user a chance to read the message (in case of batch moding)
	read
	exit 1
else
	echo "required dependencies verified."
fi

# this may look useless, but if overwriting is denied, we will want to know that it happened here and not in the process_dir function
echo "generating xml header..."
# this will overwrite any existing file inplace
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > sections.list
# dont mention about setting the other variables because that doesnt take long or have any potential to fail
echo "calculating file and directory counts..."

###########################  INDENTS - level which operating on (-1=outside) 
# SET INITIAL DIRECTORY   #  MAXTITLELEN - max length of a title element to  
# SET INDENTS TO -1       #                use for output                    
###########################  *COUNT used for calculating percentage done     
# use fallback sizes of (default 80x25) if resize / checkwinsize fails
# needed for funtionality on dumb or severely stupid terminals!! (like null terms)
declare -i FALLBACK_SCREEN_WIDTH=80
declare -i FALLBACK_SCREEN_HEIGHT=25
declare -g INITDIR=$PWD
declare -ig INDENTS=-1
declare -ig MAXTITLELEN=71
declare -ig TOTALCOUNT=0
declare -i INDEXCOUNT=$(find -type f -iname 'index.htm*' | grep '.*' --count)
declare -i DIRCOUNT=$(find -type d | grep -P ".*(?<=\/\.).*" -v --count)
declare -i HTMLCOUNT=$(find -type f -iname '*.htm*' | grep '.*' --count)
# since indexes are only used for directory entries (when possible) we         
# subtract them from the final count however directories always generate       
# a tag, so we must consider them part of the count                            
declare -ig FINALCOUNT=$(( HTMLCOUNT - INDEXCOUNT + DIRCOUNT ))
declare -ix COLUMNS=0 LINES=0
eval "$(resize | sed 's/^/declare -ix /g' | grep "declare -ix (COLUMNS|LINES)\=[0-9]+;" --line-regexp -Po)"
if [[ $COLUMNS == 0 || $LINES == 0 ]]; then
	echo "Warning: can't determine terminal size, guessing standard ${FALLBACK_SCREEN_WIDTH}x${FALLBACK_SCREEN_HEIGHT} screen"
	COLUMNS=${FALLBACK_SCREEN_WIDTH}
	LINES=${FALLBACK_SCREEN_HEIGHT}
fi


# CHANGE TO RIGHT DIR                                                         #
# [[ "$PWD" != "${BASH_SOURCE%/*}" ]] && cd "${BASH_SOURCE%/*}"               #




#####################################################                         #
#### WRITE OPENING TAG FOR CURRENT DIRECTORY AND ####                         #
#### READ ALL HTML AND DIRS IN CURRENT DIRECTORY ####    A1                   #
#### INTO LISTS #####################################                         #
#####################################################                         #
# html_title [document]                                                       #
# for guarenteed-output reasons the following default behavior is:            #
#  - outputs file's text between an html <title> tag                          #
#  - filters invalid chars                                                    #
#  - chops to MAXTITLELEN                                                     #
#  - if file is unreadable, outputs filename                                  #
#                                                                             #
function html_title()
{
	local CONTEXT TITLE_RAW TITLE_COOKED TITLE_PROPER DEFAULT_TITLE
	CONTEXT=`stat "$1" --format="%s" 2>/dev/null`
	TITLE_PROPER=""
	if [[ $CONTEXT -gt 0 ]]; then
		TITLE_RAW=$(grep -Po "(?<=<title>).*(?=</title>)" "$1")
		TITLE_COOKED=${TITLE_RAW//[^A-Za-z0-9 _:.]}
		TITLE_PROPER=${TITLE_COOKED: 0:$MAXTITLELEN}
	fi
	if [[ -n $TITLE_PROPER ]]; then
		echo $TITLE_PROPER
	else
		DEFAULT_TITLE="${1##*/}"
		if [[ -n $DEFAULT_TITLE ]]; then
			echo $DEFAULT_TITLE
		else
			echo "Untitled"
		fi
	fi

}

# echo_section [type] [indenter(str)] [title] [ref]
function echo_section()
{	
	local OUT_REF=""
	local TYPE=${1}; shift
	local SUFF=""
	local PREF=""
	local -i PERCENTAGE=$(( (TOTALCOUNT * 100) / (FINALCOUNT) ))
  echo -n "[2K[sprocessing $PWD .. ${PERCENTAGE}% done[u"

	case $TYPE in
	CLOSE)	
		echo "${1}</section>" >> ${INITDIR}/sections.list
		;;
	OPENCLOSE)
		# self closing, and prefix with a tab because it opens and self-closes
		SUFF="/"
		PREF="\t"
		# set the reference to include this directory, if it isn't the root
		[[ $INITDIR == $PWD ]] && OUT_REF=${3} || OUT_REF=${PWD#$INITDIR/}/${3}		
		;;&
	OPEN)
		# check for index file first
		# true: it's a file (the index) so treat it that way, it will always be non-root because it's an opening dir tag
		# false: directory is the name, so we dont need to use it ($3) at all
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

# process_dir [dirname]                                                       #
function process_dir()
{
	# local variables (must have for recursion)                                 #
	local ITEM DIR INDENTER ot_ref ot_title INDEXES kk
	# increment the indent level, note PREFIX and not postfix, and cd on lev>0  #
	((++INDENTS))
	#printf "\n%2s %$[COLUMNS-4]s\n" "$INDENTS" "$PWD"
	if [[ $INDENTS -gt 0 ]]; then
		cd "$1"
	fi
	INDENTER=""
	if [[ $INDENTS -gt 0 ]]; then
		#echo "set indenter"
		INDENTER=$(eval printf "\\\t%.0s" {1..$INDENTS})
	else
		INDENTER=""
	fi
	#echo "\n$INDENTER Level $INDENTS"
	#for ((kk=0;kk<INDENTS;kk++)); do INDENTER+="\t"; done

  # scan index for opening tag data or prepare a dummy tag
	INDEXES=(index.@(html|htm))
	# note: PWD will be tacked on in echo_section, dont pass it here
	if [[ ${#INDEXES[@]} == 0 ]]; then
		ot_ref="${1#/}"
		ot_title="${PWD##*/}"
	else
		ot_ref="${INDEXES[-1]}"
		ot_title=$(html_title $ot_ref)
	fi

	# create opening tag                                                       #
	echo_section OPEN "${INDENTER}" "$ot_title" "$ot_ref"	
	# process HTML files                                                       #
	for ITEM in !(index).html !(index).htm; do
		ot_title=$(html_title $ITEM)
		ot_ref=${ITEM}
		# please read about UNDERSTANDING INDENTATION on why the extra's needed  #
		echo_section OPENCLOSE "${INDENTER}" "$ot_title" "$ot_ref"
	done
	#  process subdirs (if any) - variables will be preserved as needed        #
	#  this is recursive, so be careful and keep locals and globals separated  #
	for DIR in */; do
		process_dir "${DIR}"
	done
	# create the closing tag  #
	echo_section CLOSE "${INDENTER}"

	# decrement (note that it is now POSTFIX not prefix & cd if not at 0-lev  
	((INDENTS--))	&& cd .. 	
	
}

## UNDERSTANDING INDENTATION - why an extra \t is needed for file entries    
#dir              indenter				      with file indent        without it   
#/dir			   			1                    	<dir>                   <dir>        
#/dir/file        1                      	<file\>               <file\>      
#/dir/file        1                      	<file\>               <file\>      
#/dir/dir         2                      	<dir>                  	<dir>      
#/dir/dir/file1   2                        	<file1>              	<file1>    
#/dir/dir/file2   2                        	<file2>              	<file2>    
#/dir/dir/file3   2                        	<file3>              	<file3>    
#/dir/dir (end)   2                        </dir>                 </dir>     
#/dir/dir2        2                        <dir2>                 <dir2>     
#/dir/dir2/file   2                        	<file>              	<file>     
#/dir/dir2 (end)  2                        </dir2>                </dir2>    
#/dir (end)       1                    	<dir>                   <dir>        

#  /dir                  1          	<dir>                                                    
#  /dir/dir              2          		<dir> 
#  /dir/dir/dir          3          			<dir> 
#  /dir/dir/dir (end)    3          			</dir>    
#  /dir/dir/dir          3          			<dir>  
#  /dir/dir/dir/file     3          				<file>
#  /dir/dir/dir (end)    3          			</dir>  
#  /dir/dir (end)        2          		</dir>  
#  /dir (end)            1          	</dir>  
#
# As plainly seen, without file indentation, regardless of the level or      
# position of ordering the dir/file, files would either line up with dirs    
# and be hard to read, the other option is to reassign INDENTER more than    
# one time per iteration which is just plain inefficient, in the above       
# test, we see that only file indentation does the job just fine             
# Most standards including W3C, define self-closing tags to be indented but  
# but not half-closed tags. The indentation increases when a tag is opened,  
# and decreases when the tag is closed, so essentially, the indents are being
# incremented and decremented in one swoop. But since that would be very in- 
# efficient, a \t is simply added for those items. Hope that clears it up.   
#################################                                            
#### ITERATE THROUGH LIST:   ####
#### GET NEXT ITEM IN LIST   #### A2
#################################

#### IS ITEM DIRECTORY ? ####### Q1
   # YES save current directory state and
   #     increment indent and go to ITERATE[A1]     
   #     using said directory item

##### IS ITEM FILE ? Q2
    # YES write tag and title with indents 
		#  NO check for list end or echo error if file isnt html

##### AT END OF LIST? Q3
		# YES: pop dir from stack, write closing tag and return
		#  NO: continue above iteration with next item

################
#  END         #
################

# used when exiting (if we make it to the end) TODO: move this to the var declaration block
declare -i RETV=1
# start - also separates any failure messages from being from the function process_dir
echo "preparing to process files..."
process_dir "."
# cd "$INITDIR" should not need this unless you have a weird source tree littered with symlinks which somehow managed to work with the above
# check for exists first before doing any post checking
[[ -r sections.list ]] && echo "\nfinished, sections.list is $(stat sections.list --format='%s') bytes long" || { echo "\ndone, but sections.list not created (failed!)"; exit 1; }
echo "validating xml structure..."
if xmlstarlet val -w -e sections.list; then
	echo "validation suceeded, file is ready for insertion into qhp."	
	RETV=0 #good to go, this is the final green light for make (actually make-boost-qhp.sh gets this value and passes it to make at the end)
else
	echo "validation failed. file not well formed, so we can't use it. see error above for details or contact the author if you think this is a bug."
fi

# RESTORE CURRENT DIR
popd &> /dev/null
# give back code, make-boost-qhp.sh will use it to determine if it's ok to generate the .qhp
exit ${RETV}
