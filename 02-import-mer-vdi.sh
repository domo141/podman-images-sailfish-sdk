#!/bin/sh
#
# Author: Tomi Ollila -- too ät iki piste fi
#
# Created: Fri 02 Aug 2019 14:00:12 EEST too
# Last modified: Tue 13 Aug 2019 20:43:43 +0300 too

# SPDX-License-Identifier: Apache-2.0

case ${BASH_VERSION-} in *.*) set -o posix; shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) emulate ksh; esac

set -euf  # hint: sh -x thisfile [args] to trace execution

die () { printf '%s\n' "$@"; exit 1; } >&2
warn () { printf '%s\n' "$*"; } >&2

echo
ev=0
for c in podman guestfish newuidmap newgidmap
do
	command -v $c >/dev/null || { warn "'$c': no such command"; ev=1; }
done
test $ev = 0 || die "Required commands missing"
unset ev c

ipath=`exec sed -n '/^Exec=/ { s/.....//; s:/bin/qtcreator.*::; p; q; }' \
	$HOME/.local/share/applications/SailfishOS-SDK-qtcreator.desktop`

case $ipath
 in 	'') die "Cannot find sdk installation path"
 ;;	 *"'"*) die " 's in sdk installation path \"$ipath\""  # for eval below
esac

subidcnt () {
	v=cnt_$2
	set -- `exec podman unshare cat /proc/self/$1`
	shift $(($# - 3))
	eval $v='$(($1 + $3))'
}

id
subidcnt uid_map uid ; echo number of available subuids: $cnt_uid
subidcnt gid_map gid ; echo number of available subgids: $cnt_gid
pass=true
if test $cnt_uid -lt 100001
then	m=$((100001 - cnt_uid))
	warn "too few subuids ($cnt_uid): at least 100001 ($m more) required"
	pass=false
fi
if test $cnt_gid -lt 100002
then	m=$((100002 - cnt_gid))
	warn "too few subgids ($cnt_gid): at least 100002 ($m more) required"
	pass=false
fi
$pass || die 'Configure more subordinate uids or gids in /etc/sub?id' \
	     ' run  podman unshare head /proc/self/uid_map /proc/self/gid_map'\
	     '  to see the numbers at any time' \
	     '(I had to run `kill -9 -1` to get these mappings updated...)'
unset pass cnt_uid cnt_gid v m

# we could source (.) but that could be bad example

sdk_ver=`exec sed -n s/SDK_RELEASE=//p "$ipath"/sdk-release`

test "$sdk_ver" || die "Cannot figure out sdk release information"

case $sdk_ver in *[!0-9.]*) die "Unsupported characters in '$sdk_ver'"
esac

echo
if podman images -n --format='Image: {{.Repository}}:{{.Tag}} {{.Created}}' |
	grep sailfish-sdk-mer-vdi:$sdk_ver'\>'
then
	echo Target image exists.
	echo Continue to execute 03-mk-buildengine.sh
	echo
	exit 0
fi

echo 'Executing (takes a while to complete -- run top(1) to observe):'
sp="
guestfish --ro -a '$ipath/mersdk/mer.vdi' -i <<EOF
tar-out / - | podman import - localhost/sailfish-sdk-mer-vdi:$sdk_ver
EOF
"
echo "$sp"
eval "$sp"

echo
echo Done. Continue to execute 03-mk-buildengine.sh
echo


# Local variables:
# mode: shell-script
# sh-basic-offset: 8
# tab-width: 8
# End:
# vi: set sw=8 ts=8
