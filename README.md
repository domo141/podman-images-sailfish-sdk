
Podman Images for Sailfish (app) SDK
====================================

Instead of VirtualBox use running (rootless) container managed by podman
as Sailfish OS Build Engine.

The Sailfish OS Build Engine (podman) container image is built on top
of "mer vdi" container image -- an image extracted "verbatim" from
`mer.vdi` image file distributed inside SailfishSDK installer. Recreating
this image is almost reproducible -- timestamp in container metadata makes
the final container id hash change (fs layer gets same id hash every time)...

(Some minor adaptation was required on to get build engine image working,
 see file `03-mk-buildengine.sh` for details.)

### thanks

In order to get this working, even without bringing real VirtualBox near the
filesystem of the machines I've tested this (*) I looked quite a bit at

    CODeRUS/docker-sailfishos-buildengine/blob/master/helpers/VBoxManage

so thanks, CODeRUS !

(*) VirtualBox is great software, but quite intrusive (reinstall required to
    get fully rid of it); therefore I don't want to have it installed in all
    of my machines (if in any at any given time).


tl;dr; experiment
-----------------

Have podman, guestfish, curl, newuidmap, newgidmap installed, enough subuids
and subgids, app sdk installer downloaded -- and the following could work...

    mkdir $HOME/thome
    HOME=$HOME/thome ./01-install-sdk.sh SailfishSDK-2.2.4-linux64-offline.run
    HOME=$HOME/thome ./02-import-mer-vdi.sh
    HOME=$HOME/thome ./03-mk-buildengine.sh 2.2.4
    HOME=$HOME/thome ./bin/VBoxManage start ;: startup slow on some systems...
    HOME=$HOME/thome ./run-qemu.sh
    cp $HOME/thome/SailfishOS/mersdk/targets/xcache/Sailfish_OS-3.1.0.12-* .
    : rm -rf $HOME/thome


Requirements
------------

Kernel new enough, 4.1x (where x is high enough) may work. For best results
5.x.

Podman, guestfish (libguestfs-tools), curl, new enough shadow-utils (for
newuidmap and newgidmap commands) installed.

fuse-overlayfs if available (and hopefully (rootless) podman will use it),
then starting container is usually instantaneous -- when (fallback) *vfs*
storage driver is used starting container is slow (copies fs content ?).

Enough subordinate uids and gids. In mer.vdi user nemo has uid 100000
and gid 100001.

In one of my machines, I see the following:

    $ podman unshare head /proc/self/uid_map /proc/self/gid_map
    ==> /proc/self/uid_map <==
             0       1000          1
             1     100000      65536
         65537   10000000      34464

    ==> /proc/self/gid_map <==
             0       1000          1
             1     100000      65536
         65537   10000000      34465

In that case, `/etc/subuid` had the following content:

    user:100000:65536
    other:165536:65536
    user:10000000:34464

it is not hard to guess how `/etc/subgid` looked like.

It is easier to edit those files than using `usermod --add-subuids`,
and it makes no difference what is required to get the changed mappings
"activated". For me not just re-login, but `kill -9 -1` was required
to get the new mappings to work (and `podman ps -aq | xargs podman rm`
to get noisy accumulated container leftovers to disappear).


Install
-------

Installation is executed in many steps -- which all may not need to be
executed. E.g. if Sailfish Application SDK is already installed,
`01-install-sdk.sh` may not be needed to be executed (although the `mer.vdi`
(embedded) in other than tested Application SDKs may not work as expected).

Note that VirtualBox is not used at all.

Also a separate test-installation can be done by setting `$HOME` point to
other directory where it currently points. see **tl;dr;** section above
for hint.

Many steps can be retried (just remove related components informed after
corresponding script refuses to execute). To avoid re-fetching SDK targets
copy files from *xcache* (see tl;dr; above) to *this* directory for reuse
(for redoing step #01).


### ./01-install-sdk.sh

If there is already (suitable) Application SDK installer this step can be
skipped. The `mersdk/mer.vdi` available in installation directory will be
used in next step.

`01-install-sdk.sh` does the following:

* checks if Sailfish Application SDK is already installed

* checks for known Sailfish Application SDK Installer given as command
  line argument.

* prints hints what to configure in Installer GUI

* adds equivalent of `/bin/true` as `VBoxManage` (bin-01/VBoxManage)
  to be available in `$PATH` and executes the installer.


### ./02-import-mer-vdi.sh

Imports podman image using fs image in `mersdk/mer.vdi`, but before that:

* checks whether Sailfish Application SDK is installed

* checks the existence of required tools

* checks whether (podman) image of the sailfish-sdk-mer-vdi:{sdkver} exists

* if all good, executes (without further interaction)

      guestfish --ro -a 'path/to/mersdk/mer.vdi' -i <<EOF
      tar-out / - | podman import - localhost/sailfish-sdk-mer-vdi:$sdk_ver
      EOF

  This may fail, but the error messages are pretty clear on how to proceed
  (e.g. chmod kernel image) before retrying. This may also be slow -- just
   be patient and check with `top(1)` where time is spent.


### ./03-mk-buildengine.sh

Runs (podman) container from image sailfish-sdk-mer-vdi:{sdkver}, and writes
new (podman) image sailfishos-buildengine:{trgver} after modifications.

Most modifications are to mitigate the resistance of running commands as
**root** user -- Inside "rootless" podman container the user outside
container is mapped as user root inside the container -- which is very
convenient feature and simplifies container developments in great deal, but
is naturally undesirable situation in "normal" environments.

Next, `tar(1)` fails `mknod(2)`ing files -- which is strange, but no desire
to investigate that further just now -- so that is run via shell wrapper
which just ignores the return value...

`./03-mk-buildengine.sh` takes *sdk-release* as command line argument -- I
just noticed it will resolve it from sdk installation (late change, added
*xcache* to avoid re-fetching `...-Sailfish_SDK_Target-armv7hl.tar.7z`
every time) -- perhaps I change that later...

For more information of the changes look into the script. It executes the
same script in host and then on running container, different parts of it.

This file is likely to change most in the future -- and to avoid maintain
burden I'm not documenting more of what it does here :D


### bin/VBoxManage

This the `VBoxManage` replacement which is used to avoid VirtualBox use
(and installation). Most thanks to CODeRUS for most of the interface
content. I added something -- and, especially, for user convenience --
`start`, `stop` and `shell` commands.

I suggest trying `start` before running this via SDK qtcreator -- first of
all to observe the startup delay (without (fuse-)overlayfs it may be long).

This can be copied, symlinked (that's how I would do it) to user's $PATH,
or -- alternatively -- use `./run-qtcreator.sh` to run SDK Dev Env (that's
how I'm currently doing it)...


### ./run-qtcreator.sh

`run-qtcreator.sh` can be used to (test) execute Sailfish Application SDK
without pre-making `bin/VBoxManage` available in $PATH. The current
"limitation" is that these 2 files needs to be in same directory hierarchy
(so no copying around). There are options, which are to be considered later.

Try it!  I hope many of you find it useful!  Some things may even work!

Tomi
