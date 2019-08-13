#!/bin/sh

case ${BASH_VERSION-} in *.*) set -o posix; shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) emulate ksh; esac

set -eu  # hint: sh -x thisfile [args] to trace execution

ipath=`exec sed -n '/^Exec=/ { s/.....//; s:/bin/qtcreator.*::; p; q; }' \
	$HOME/.local/share/applications/SailfishOS-SDK-qtcreator.desktop`

test "$ipath" || {
	echo "Cannot find sdk installation path"; exit 1;
} 2>/dev/null

case $#${1-} in '1!') ;;
*)	echo
	echo "Run $0 '!' to remove sailfish sdk files matching"
	echo
	echo "$HOME/.local/share/applications/SailfishOS-SDK-*"
	echo "$HOME/.local/share/icons/*/*/SailfishOS-SDK-*"
	echo "$HOME/.config/SailfishOS-SDK/"
	echo "$ipath/"
	echo
	echo Podman containers '(or any others)' left untouched.
	echo
	exit
esac

set -v
rm -rf "$HOME"/.config/SailfishOS-SDK
rm -rf "$ipath"
rm -rf "$HOME"/.local/share/icons/hicolor/*/*/SailfishOS-SDK-*
rm -rf "$HOME"/.local/share/applications/SailfishOS-SDK-*
exit


# Local variables:
# mode: shell-script
# sh-basic-offset: 8
# tab-width: 8
# End:
# vi: set sw=8 ts=8
