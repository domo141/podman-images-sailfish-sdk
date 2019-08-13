#!/bin/sh
#
# Author: Tomi Ollila -- too ät iki piste fi
#
# Created: Wed 31 Jul 2019 15:14:04 EEST too
# Last modified: Tue 13 Aug 2019 00:15:16 +0300 too

# SPDX-License-Identifier: Apache-2.0

case ${BASH_VERSION-} in *.*) set -o posix; shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) emulate ksh; esac

set -euf  # hint: sh -x thisfile [args] to trace execution

die () { printf '%s\n' "$@"; exit 1; } >&2

x () { printf '+ %s\n' "$*" >&2; "$@"; }
x_env () { printf '+ %s\n\n' "$*" >&2; sleep 1; env "$@"; }

test $# = 2 && test $2 = '!' && { force=true; set -- "$1"; } || force=false

test $# = 1 || {
	exec >&2
	echo; echo Usage: $0 '[path/to/]SailfishSDK...run'; echo
	exit 1
}

test -f "$1" || die "'$1': no such file"

set_ipath () {
    ipath=`exec sed -n '/^Exec=/ { s/.....//; s:/bin/qtcreator.*::; p; q; }' \
	"$HOME"/.local/share/applications/SailfishOS-SDK-qtcreator.desktop \
	2>/dev/null` || :
}
set_ipath

if test "$ipath" && test $force = false
then
	exec >&2
	echo
	echo SailfishOS-SDK has already been installed at
	echo $ipath/.
	test -d "$ipath" || printf %s\\n \
		'(directory nonexistent but referenced by' \
		" ~/.local/share/applications/SailfishOS-SDK-qtcreator.desktop)"
	echo
	echo Append "'!'" to the command line to force new installation.
	echo
	exit 1
fi

echo Checksumming $1 -- this may take some time...
sha256sum=`exec sha256sum "$1"`
case $sha256sum
in	230a8813bf49b0308cd30899c6f722ed704aa2dbae8e12f2203f456ad69a5115*)
		sdk_ver=2.1.1 # SailfishSDK-2.1.1-linux64-offline.run
;;	3f63711cf958bc7c36704f4a4acd3c4e03efbd0e587055d1da840e2d7e7ab1ca*)
		sdk_ver=2.2.4 # SailfishSDK-2.2.4-linux64-offline.run
;;	*) die "Unknown SDK installer image": "$sha256sum"
esac

unset sdk_ver # currently unused...

case $0 in /*)	dn0=${0%/*}
	;; */*/*) dn0=`exec realpath ${0%/*}`
	;; ./*)	dn0=$PWD
	;; */*)	dn0=`exec realpath ${0%/*}`
	;; *)	dn0=$PWD
esac

test -f "$dn0/bin-01/VBoxManage" ||
	die "Internal error:" "  $dn0/bin-01/VBoxManage does not exist"

case $1 in */*) i=$1 ;; *) i=./$1 ;; esac

test -x "$1" || x chmod +x "$1"

echo
echo ' ' After pressing ENTER, SDK installation from
echo "       '$1'"
echo ' ' will begin.
echo ' ' I suggest you stick mostly with defaults, especially installing
echo ' ' components to '"virtual machine" will fail (be no op)', therefore
echo ' ' no point there.
echo
echo ' ' '"Sailfish OS Emulators"' can be removed to save time, space and
echo ' ' InstallationLog.txt content, those are not supported...
echo
echo ' ' Also, starting Qt Creator at the end of the installation is not very
echo ' ' useful, as there are more installation scripts to be executed...
read a
echo
echo Executing...
x_env PATH=$dn0/bin-01:$PATH "$i"

echo
set_ipath
echo Installation complete.
echo "'$ipath/InstallationLog.txt'" may be interesting...
echo
echo Next, continue to execute 02-import-mer-vdi.sh
echo


# Local variables:
# mode: shell-script
# sh-basic-offset: 8
# tab-width: 8
# End:
# vi: set sw=8 ts=8
