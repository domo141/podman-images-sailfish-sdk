#!/bin/sh
#
# Author: Tomi Ollila -- too ät iki piste fi
#
#       Copyright (c) 2019 Tomi Ollila
#           All rights reserved
#
# Created: Fri 02 Aug 2019 14:37:08 EEST too
# Last modified: Tue 27 Aug 2019 00:01:12 +0300 too

# SPDX-License-Identifier: Apache-2.0

# Some of the content here is based on
#     .../CODeRUS/docker-sailfishos-buildengine/

case ${BASH_VERSION-} in *.*) set -o posix; shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) emulate ksh; esac

set -euf  # hint: sh -x thisfile [args] to trace execution

die () { printf '%s\n' "$*"; exit 1; } >&2

x () { printf '+ %s\n' "$*" >&2; "$@"; }

test $# = 1 || die "Usage: $0 sdk_release (used for choosing podman image)"

if test "$1" != '--in-container--'
then
	case $1
	in  2.1.1 | 3.0.3.9 )  sdkver=2.1.1 trgver=3.0.3.9
	;;  2.2.4 | 3.1.0.12 ) sdkver=2.2.4 trgver=3.1.0.12
	;;	*) die "'$1':unknown sdk_release"
	esac

	if podman images -n --format='{{.Repository}}:{{.Tag}} {{.Created}}' |
		grep sailfishos-buildengine:$trgver'\>'
	then
		echo Target image exists.
		exit 0
	fi

	podman inspect sailfish-sdk-mer-vdi:$sdkver --format '{{.Size}}'

	case $0 in /*)	dn0=${0%/*}
		;; */*/*) dn0=`exec realpath ${0%/*}`
		;; ./*)	dn0=$PWD
		;; */*)	dn0=`exec realpath ${0%/*}`
		;; *)	dn0=$PWD
	esac

	sdk=`exec sed -n '/^Exec=/ { s/.....//; s:/bin/qtcreator.*::; p; q; }'\
	    "$HOME/.local/share/applications/SailfishOS-SDK-qtcreator.desktop"`

	test "$sdk" || die "Cannot find SailfishOS SDK install path"

	target_t7z=Sailfish_OS-${trgver}-Sailfish_SDK_Target-armv7hl.tar.7z

	xcache=$sdk/mersdk/targets/xcache
	test -d $xcache || mkdir $xcache
	test -f $xcache/$target_t7z || {
		if test -f "$dn0"/$target_t7z
		then echo $dn0/$target_t7z exists; dn0=
		elif test -f "$PWD"/$target_t7z
		then echo $dn0/$target_t7z exists; dn0=
		fi
		test "$dn0" || {
			echo copy/move it to $xcache/
			echo '(to skip download) then retry'
			exit 1
		}
		x curl -o $xcache/wip.$$ \
		     https://releases.sailfishos.org/sdk/targets/$target_t7z
		mv $xcache/wip.$$ $xcache/$target_t7z
	}

	# hints: podman exec -it sailfishos-buildengine-wip bash
	#        podman start -ai sailfishos-buildengine-wip
	#        podman rm sailfishos-buildengine-wip

	x podman run -it --privileged -v "$dn0:/mnt" \
		-v "$sdk/mersdk/targets:/host_targets" \
		--tmpfs /tmp:rw,size=65536k,mode=1777 --net=none \
		--name sailfishos-buildengine-wip --env trgver=$trgver \
		sailfish-sdk-mer-vdi:$sdkver /mnt/"${0##*/}" --in-container--
	echo 'back in "host" environment...'

	x podman unshare sh -eufxc '
		mp=`exec podman mount sailfishos-buildengine-wip`
		( cd "$mp"; rm -rfv run; exec mkdir -m 755 run )
	'
	x podman commit sailfishos-buildengine-wip sailfishos-buildengine:$trgver
	podman rm sailfishos-buildengine-wip
	echo
	echo all done
	echo
	echo Copy '(or symlink)' bin/VBoxManage to your '$PATH'
	echo or just try/use ./run-qtcreator.sh
	echo
	exit 0
fi

# rest of the file executed in container #

echo --
echo -- Executing in container -- xtrace now on -- >&2
echo --

if test -f /.rerun
then
	echo 'failure in previous execution -- starting "rescue" shell'
	echo
	exec /bin/bash
fi
:>/.rerun

set -x

test -f /run/.containerenv || die "No '/run/.containerenv' !?"

# rm /etc/mer-sdk-vbox # no, better this than /etc/mer-sdk-chroot

# in rootless podman container host used id/group is mapped to 0 (root)
chown 0:0 /home/mersdk
# ditto
sed -i s/MERSDK=1001/MERSDK=0/ /etc/mersdk.env.systemd
# and more
sed -i '/mersdk:/ s/1001/0/' /etc/passwd

# again ... allow sdk-manage to execute as uid 0 (and sdk-assistant)
sed -i '/EUID/ s/-eq/-lt/' /usr/bin/sdk-manage /usr/bin/sdk-assistant

# let's (temporarily) wrap it, so we get logs how it is executed

mv /usr/bin/sdk-manage /usr/bin/sdk-manage.it

printf %s\\n > /usr/bin/sdk-manage '#!/bin/sh' '' \
	'echo $# : $@ >> /tmp/sdk-manage.log' \
	'exec /usr/bin/sdk-manage.it "$@"'
chmod 755 /usr/bin/sdk-manage

# (temporarily) wrap tar, mostly for ignoring return value
# due to: /bin/tar: ./dev/zero: Cannot mknod: Operation not permitted ...

printf %s\\n > /usr/local/bin/tar '#!/bin/sh' '' \
	'echo $# : $@ >> /tmp/tar.log' \
	'/bin/tar "$@"' 'exit 0'
chmod 755 /usr/local/bin/tar

# (temporarily) hax #mer-tooling-chroot to not fail... (was lucky this one
# change worked at least once) -- whether something broke is another issue...

sed -i 's/mount /#mount /' \
	/srv/mer/toolings/SailfishOS-${trgver}/mer-tooling-chroot

target_t7z=Sailfish_OS-${trgver}-Sailfish_SDK_Target-armv7hl.tar.7z

# install a target...
xcache=/host_targets/xcache
sdk-manage target install SailfishOS-$trgver-armv7hl $xcache/$target_t7z

# more tunes(/haxes?) to make mersdk accessible via ssh

usermod -U mersdk
usermod -p nopw mersdk

sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config_engine

# write out init

sed '1,/^__E[N]D__/d;/^__E[O]F__/Q' "$0" > /sbin/minute.pl # 'Q' is GNU extensi
chmod 755 /sbin/minute.pl

# some extra cleanups (seen in podman diff sailfishos-buildengine:{trgver})

# well, this did not work --tmpfs to the rescue (and we lose tar.log etc)
#set +f
#chmod -R 777 /tmp/sb2--20*
#rm -rfv /tmp/sb2--20*

rm /.rerun
:
: all done in container
:
exit

__END__
#!/usr/bin/perl

# mini init #

use 5.8.1;
use strict;
use warnings;

use POSIX ":sys_wait_h";

$SIG{CHLD} = sub { 1 while (waitpid(-1, WNOHANG) > 0) };

system qw"/usr/sbin/sshd -p 2222 -e -f /etc/ssh/sshd_config_engine";

unless (fork) {
	chdir q"/usr/lib/sdk-webapp-bundle";
	exec qw"/usr/bin/ruby /usr/bin/puma -p 8080 -t 1:1 -e production"
}
sleep 1234567890 while (1)

__EOF__


# Local variables:
# mode: shell-script
# sh-basic-offset: 8
# tab-width: 8
# End:
# vi: set sw=8 ts=8
