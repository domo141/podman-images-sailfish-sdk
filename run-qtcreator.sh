#!/bin/sh
#
# Author: Tomi Ollila -- too ät iki piste fi
#
# Created: Sat 03 Aug 2019 16:53:39 EEST too
# Last modified: Sat 03 Aug 2019 16:58:28 +0300 too

# SPDX-License-Identifier: Apache-2.0

case ${BASH_VERSION-} in *.*) set -o posix; shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) emulate ksh; esac

set -euf  # hint: sh -x thisfile [args] to trace execution

die () { printf '%s\n' "$*"; exit 1; } >&2

ipath=`exec sed -n '/^Exec=/ { s/.....//; s:/bin/qtcreator.*::; p; q; }' \
	$HOME/.local/share/applications/SailfishOS-SDK-qtcreator.desktop`

test "$ipath" || die "Cannot find sdk installation path"

case $0 in /*)	dn0=${0%/*}
	;; */*/*) dn0=`exec realpath ${0%/*}`
	;; ./*)	dn0=$PWD
	;; */*)	dn0=`exec realpath ${0%/*}`
	;; *)	dn0=$PWD
esac

x_exec_env () { printf '\n+ %s\n\n' "$*" >&2; exec env "$@"; }

x_exec_env PATH=$dn0/bin:$PATH $ipath/bin/qtcreator


# Local variables:
# mode: shell-script
# sh-basic-offset: 8
# tab-width: 8
# End:
# vi: set sw=8 ts=8
