#! /bin/sh
#	$NetBSD: mkinit.sh,v 1.2 2004/06/15 23:09:54 dsl Exp $

# Copyright (c) 2003 The NetBSD Foundation, Inc.
# All rights reserved.
#
# This code is derived from software contributed to The NetBSD Foundation
# by David Laight.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of The NetBSD Foundation nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
# ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

srcs="$*"

nl='
'
openparen='('
backslash='\'

includes=' "shell.h" "mystring.h" "init.h" '
defines=
decles=
event_init=
event_reset=
event_shellproc=

for src in $srcs; do
	exec <$src
	decnl="$nl"
	while IFS=; read -r line; do
		[ "$line" = x ]
		case "$line " in
		INIT["{ 	"]* ) event=init;;
		RESET["{ 	"]* ) event=reset;;
		SHELLPROC["{ 	"]* ) event=shellproc;;
		INCLUDE[\ \	]* )
			IFS=' 	'
			set -- $line
			# ignore duplicates
			[ "${includes}" != "${includes%* $2 }" ] && continue
			includes="$includes$2 "
			continue
			;;
		MKINIT\  )
			# struct declaration
			decles="$decles$nl"
			while
				read -r line
				decles="${decles}${line}${nl}"
				[ "$line" != "};" ]
			do
				:
			done
			decnl="$nl"
			continue
			;;
		MKINIT["{ 	"]* )
			# strip initialiser
			def=${line#MKINIT}
			comment="${def#*;}"
			def="${def%;$comment}"
			def="${def%%=*}"
			def="${def% }"
			decles="${decles}${decnl}extern${def};${comment}${nl}"
			decnl=
			continue
			;;
		\#define[\ \	]* )
			IFS=' 	'
			set -- $line
			# Ignore those with arguments
			[ "$2" = "${2##*$openparen}" ] || continue
			# and multiline definitions
			[ "$line" = "${line%$backslash}" ] || continue
			defines="${defines}#undef  $2${nl}${line}${nl}"
			continue
			;;
		* ) continue;;
		esac
		# code for events
		ev="${nl}      /* from $src: */${nl}      {${nl}"
		while
			read -r line
			[ "$line" != "}" ]
		do
			# The C program indented by an extra 6 chars using
			# tabs then spaces. I need to compare the output :-(
			indent=6
			while
				l=${line#	}
				[ "$l" != "$line" ]
			do
				indent=$(($indent + 8))
				line="$l"
			done
			while
				l=${line# }
				[ "$l" != "$line" ]
			do
				indent=$(($indent + 1))
				line="$l"
			done
			[ -z "$line" -o "$line" != "${line###}" ] && indent=0
			while
				[ $indent -ge 8 ]
			do
				ev="$ev	"
				indent="$(($indent - 8))"
			done
			while
				[ $indent -gt 0 ]
			do
				ev="$ev "
				indent="$(($indent - 1))"
			done
			ev="${ev}${line}${nl}"
		done
		ev="${ev}      }${nl}"
		eval event_$event=\"\$event_$event\$ev\"
	done
done

exec >init.c.tmp

echo "/*"
echo " * This file was generated by the mkinit program."
echo " */"
echo

IFS=' '
for f in $includes; do
	echo "#include $f"
done

echo
echo
echo
echo "$defines"
echo
echo "$decles"
echo
echo
echo "/*"
echo " * Initialization code."
echo " */"
echo
echo "void"
echo "init() {"
echo "${event_init%$nl}"
echo "}"
echo
echo
echo
echo "/*"
echo " * This routine is called when an error or an interrupt occurs in an"
echo " * interactive shell and control is returned to the main command loop."
echo " */"
echo
echo "void"
echo "reset() {"
echo "${event_reset%$nl}"
echo "}"
echo
echo
echo
echo "/*"
echo " * This routine is called to initialize the shell to run a shell procedure."
echo " */"
echo
echo "void"
echo "initshellproc() {"
echo "${event_shellproc%$nl}"
echo "}"

exec >&-
mv init.c.tmp init.c