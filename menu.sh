#!/bin/bash

orelse="||"

# ansi
[[ $DISPLAY ]] && 
{ 
	dim="38;5;238"
	sel="38;5;51" 
} || 
{
	dim="30;1"
	sel="36;1"
}


# codes
Margin=$(printf " %.0s" {0..${MENU_MARGIN-0}})
if [[ -z $MENU_MARGIN ]] || [[ $MENU_MARGIN == 0 ]]; then Margin=" "; fi
Anchor='[s' Return='[u'
Home='[H'   End='[F'
Up='[A'			Left='[D'
Down='[B'   Right='[C'

# numeric
declare -gi First=0				
declare -gi Last=$(( $# - 1 ))
declare -gi Current=$First
declare -ga ITEMS=("$@")
declare -g REPLY=""

function printf()
{
	command printf "$@" > $(tty)
}

function _draw()
{
printf "$Anchor"
for ((i=First;i<=Last;i++)); do
	local ti="${ITEMS[i]}"
	if ((i == Current)); then
		printf "$Margin[${sel}m$ti[${dim}m$Margin"
	else
		printf "$Margin[${dim}m$ti[${dim}m$Margin"
	fi
done
printf "$Return"
}

if (( $# <= 1 )); then
    echo "Not enough items -- you need at least 2 items to have a menu."
else
		_draw
		REPLY="NONE"
	while [[ $REPLY != "" ]]; do
		unset REPLY
		read -sn3
		case $REPLY in
			$Left|$Up)
			if ((Current > First)); then
				 ((Current--))
			else
				beep
			fi
			;;
			$Right|$Down)
			if ((Current < Last)); then
				((Current++))
			else
				beep
			fi                                                                                                                                                                                                                                                                                    
			;;
		esac
		_draw
	done
fi
case $- in
 #[i]nteractive mode no need to echo : grab the variable
	*i*)
				REPLY=${ITEMS[Current]};;
	*)
				echo ${ITEMS[Current]};;
esac


		






