#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

DARCH=$(uname --machine)
TARCH=""
EMUL=""

BASE="stable"

# STANDARD DISTRO
# - HeyDesktop!, (All of the Hey! Software included)

#PACKAGES=""
#PACKAGES64=""
#PACKAGES32=""

# XFCE DISTRO
# - XFCE, (All of the XFCE Software included, and some of Hey! Software)

PACKAGES="aptitude flatpak snap gnome-software gnome-software-plugin-flatpak gnome-software-plugin-snap firefox-esr slick-greeter tasksel-data wine wine64"
PACKAGES64=""
# PACKAGES32=""
TASKSEL="xfce-desktop"

# GNOME DISTRO
# - GNOME, (All of the GNOME Software included, and some of Hey! Software)

#PACKAGES=""
#PACKAGES64=""
#PACKAGES32=""

# PLASMA DISTRO
# - KDE PLASMA, (All of the KDE PLASMA Software included, and some of Hey! Software)

#PACKAGES=""
#PACKAGES64=""
#PACKAGES32=""

echo "Welcome to HeyTux! Builder Program"
echo
echo "What architecture do you want to build for"
echo
echo "1 x86_64"
echo "2 i386"
echo
read -p "> " arch

if [ "$arch" = "1" ]; then
	TARCH="x86_64"
	if [ "$DARCH" = "x86_64" ]; then
		echo "Building for amd64 (no emulation)"
	else
		echo "Building for amd64 using emulation."
	fi
elif [ "$arch" = "2" ]; then
	TARCH="i386"
	if [ "$DARCH" = "i386" ]; then
		echo "Building for i386 (no emulation)"
	else
		echo "Building for i386 using emulation."
	fi
else
	echo "That's not an option."
	exit
fi

echo
echo "Picked option: $arch ($TARCH)"
echo "System architecture: $DARCH"
echo "Emulation: $EMUL"
echo

if [ "$TARCH" = "x86_64" ]; then

	# Download Debian Debootstrap (if not already present)
	
	echo "Downloading Debian Debootstrap"
	
	if [ ! -d CHROOT/ ]; then
		mkdir -p CHROOT/
	fi
	
	if [ ! -d PCHROOT/ ]; then
		mkdir -p PCHROOT/
		debootstrap --arch amd64 $BASE PCHROOT/ http://deb.debian.org/debian/
	fi
	
	echo "Finished"
	
	# Remove all files from chroot, extract the downloaded tgz's, copy kernel, and we've got a chroot!
	
	echo "Removing old left overs (if any)"
	
	rm -rf CHROOT/*
	rm -rf ISO/fs.sqsh
	
	echo "Finished"
	
	echo "Copying downloaded files"
	
	cp -r PCHROOT/* CHROOT/
	
	echo "Finished"
	
	echo "Mounting chroot partitions"
	
	mount --bind /dev "CHROOT/dev"
	mount --bind /dev/pts "CHROOT/dev/pts"
	mount --bind /proc "CHROOT/proc"
	mount --bind /sys "CHROOT/sys"
	
	echo "Finished"
	
	echo "Creating a trap"
	
	cleanup()
	{
	  echo "SCRIPT TERMINATED: Unmounting partitions"
	  
	  echo "-!!!-"
	  
	  echo "IF ANY ERROR FROM UMOUNT IS REPORTED, PLEASE DO NOT REMOVE THE CHROOT/ DIRECTORY"
	  
	  echo
	  
	  echo "The only exception is if the error is a not mounted error."
	  
	  echo
	  
	  sleep 1
	
	  umount "CHROOT/dev" -l
	  umount "CHROOT/dev/pts" -l
	  umount "CHROOT/proc" -l
	  umount "CHROOT/sys" -l
	  
	  echo "Finished"
	  
	  echo
	  
	  echo "Thank you for using HeyTux!"
	  
	  trap - SIGINT SIGTERM SIGHUP EXIT
	  
	  exit
	}
	
	trap cleanup SIGINT SIGTERM SIGHUP EXIT
	
	echo "Finished"
	# Now that chroot is done, we are ready to tweak the system, install packages, install a bootloader, and finish it into an ISO.
	# Of course, use emulation, if our CPU's architecture, is not our target architecture.

	echo "Copying resources"

	cp -r RESOURCES/* CHROOT/

	echo "Done"
	
	echo "Tweaking system..."
	
	chroot CHROOT/ /bin/bash << "EOT"
		DEBIAN_FRONTEND=noninteractive apt install ca-certificates lsb-release -y
EOT
	
	cat > CHROOT/etc/apt/sources.list.d/debian.list << HEREDOC
deb [trusted=yes] http://deb.debian.org/debian/ trixie main non-free-firmware non-free contrib
deb-src [trusted=yes] http://deb.debian.org/debian/ trixie main non-free-firmware non-free contrib

deb [trusted=yes] http://security.debian.org/debian-security trixie-security main non-free-firmware non-free contrib
deb-src [trusted=yes] http://security.debian.org/debian-security trixie-security main non-free-firmware non-free contrib

deb [trusted=yes] http://deb.debian.org/debian/ trixie-updates main non-free-firmware non-free contrib
deb-src [trusted=yes] http://deb.debian.org/debian/ trixie-updates main non-free-firmware non-free contrib
HEREDOC
	
	chroot CHROOT/ /bin/bash <<"EOT"
		export DEBIAN_FRONTEND=noninteractive
	
		apt modernize-sources -y
	
		apt update -y
		
		apt upgrade -y
		
		apt install locales -y
		
		locale-gen en_US.UTF-8
		
		localectl set-locale LANG=en_US.UTF-8
		
		apt install linux-image-amd64 firmware-linux dkms -y
		
		echo "HeyTux" > /etc/hostname
		
		apt install network-manager sudo live-boot live-boot-initramfs-tools grub-common grub-efi-amd64-bin grub-efi-amd64-signed grub-efi-amd64-unsigned grub-pc-bin grub2-common tasksel -y
		
		tasksel install standard -y

		echo root:live | chpasswd

		useradd -m live

		echo live:live | chpasswd
EOT

	cat > CHROOT/etc/sudoers << HEREDOC
#
# This file MUST be edited with the 'visudo' command as root.
#
# Please consider adding local content in /etc/sudoers.d/ instead of
# directly modifying this file.
#
# See the man page for details on how to write a sudoers file.
#
Defaults        env_reset
Defaults        mail_badpass
Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# This fixes CVE-2005-4890 and possibly breaks some versions of kdesu
# (#1011624, https://bugs.kde.org/show_bug.cgi?id=452532)
Defaults        use_pty

# This preserves proxy settings from user environments of root
# equivalent users (group sudo)
#Defaults:%sudo env_keep += "http_proxy https_proxy ftp_proxy all_proxy no_proxy"

# This allows running arbitrary commands, but so does ALL, and it means
# different sudoers have their choice of editor respected.
#Defaults:%sudo env_keep += "EDITOR"

# Completely harmless preservation of a user preference.
#Defaults:%sudo env_keep += "GREP_COLOR"

# While you shouldn't normally run git as root, you need to with etckeeper
#Defaults:%sudo env_keep += "GIT_AUTHOR_* GIT_COMMITTER_*"

# Per-user preferences; root won't have sensible values for them.
#Defaults:%sudo env_keep += "EMAIL DEBEMAIL DEBFULLNAME"

# "sudo scp" or "sudo rsync" should be able to use your SSH agent.
#Defaults:%sudo env_keep += "SSH_AGENT_PID SSH_AUTH_SOCK"

# Ditto for GPG agent
#Defaults:%sudo env_keep += "GPG_AGENT_INFO"

# Host alias specification

# User alias specification

# Cmnd alias specification

# User privilege specification
root    ALL=(ALL:ALL) ALL
live    ALL=(ALL) NOPASSWD: ALL

# Allow members of group sudo to execute any command
%sudo   ALL=(ALL:ALL) ALL

# See sudoers(5) for more information on "@include" directives:

@includedir /etc/sudoers.d
HEREDOC

	cat > CHROOT/etc/os-release << HEREDOC
PRETTY_NAME="HeyTux 25.11 (skyline)"
NAME="Debian GNU/Linux"
VERSION_ID="25.11"
VERSION="25.11 (skyline)"
VERSION_CODENAME=skyline
DEBIAN_VERSION_FULL=25.11
ID=debian
HOME_URL="https://heytux.kryte.org/"
HEREDOC

	cat > CHROOT/etc/lightdm/lightdm.conf << HEREDOC
#
# General configuration
#
# start-default-seat = True to always start one seat if none are defined in the configuration
# greeter-user = User to run greeter as
# minimum-display-number = Minimum display number to use for X servers
# minimum-vt = First VT to run displays on
# lock-memory = True to prevent memory from being paged to disk
# user-authority-in-system-dir = True if session authority should be in the system location
# guest-account-script = Script to be run to setup guest account
# logind-check-graphical = True to on start seats that are marked as graphical by logind
# log-directory = Directory to log information to
# run-directory = Directory to put running state in
# cache-directory = Directory to cache to
# sessions-directory = Directory to find sessions
# remote-sessions-directory = Directory to find remote sessions
# greeters-directory = Directory to find greeters
# backup-logs = True to move add a .old suffix to old log files when opening new ones
# dbus-service = True if LightDM provides a D-Bus service to control it
#
[LightDM]
#start-default-seat=true
#greeter-user=lightdm
#minimum-display-number=0
#minimum-vt=7
#lock-memory=true
#user-authority-in-system-dir=false
#guest-account-script=guest-account
#logind-check-graphical=true
#log-directory=/var/log/lightdm
#run-directory=/var/run/lightdm
#cache-directory=/var/cache/lightdm
#sessions-directory=/usr/share/lightdm/sessions:/usr/share/xsessions:/usr/share/wayland-sessions
#remote-sessions-directory=/usr/share/lightdm/remote-sessions
#greeters-directory=\$XDG_DATA_DIRS/lightdm/greeters:\$XDG_DATA_DIRS/xgreeters
#backup-logs=true
#dbus-service=true

#
# Seat configuration
#
# Seat configuration is matched against the seat name glob in the section, for example:
# [Seat:*] matches all seats and is applied first.
# [Seat:seat0] matches the seat named "seat0".
# [Seat:seat-thin-client*] matches all seats that have names that start with "seat-thin-client".
#
# type = Seat type (local, xremote)
# pam-service = PAM service to use for login
# pam-autologin-service = PAM service to use for autologin
# pam-greeter-service = PAM service to use for greeters
# xserver-command = X server command to run (can also contain arguments e.g. X -special-option)
# xmir-command = Xmir server command to run (can also contain arguments e.g. Xmir -special-option)
# xserver-config = Config file to pass to X server
# xserver-layout = Layout to pass to X server
# xserver-allow-tcp = True if TCP/IP connections are allowed to this X server
# xserver-share = True if the X server is shared for both greeter and session
# xserver-hostname = Hostname of X server (only for type=xremote)
# xserver-display-number = Display number of X server (only for type=xremote)
# xdmcp-manager = XDMCP manager to connect to (implies xserver-allow-tcp=true)
# xdmcp-port = XDMCP UDP/IP port to communicate on
# xdmcp-key = Authentication key to use for XDM-AUTHENTICATION-1 (stored in keys.conf)
# greeter-session = Session to load for greeter
# greeter-hide-users = True to hide the user list
# greeter-allow-guest = True if the greeter should show a guest login option
# greeter-show-manual-login = True if the greeter should offer a manual login option
# greeter-show-remote-login = True if the greeter should offer a remote login option
# user-session = Session to load for users
# allow-user-switching = True if allowed to switch users
# allow-guest = True if guest login is allowed
# guest-session = Session to load for guests (overrides user-session)
# session-wrapper = Wrapper script to run session with
# greeter-wrapper = Wrapper script to run greeter with
# guest-wrapper = Wrapper script to run guest sessions with
# display-setup-script = Script to run when starting a greeter session (runs as root)
# display-stopped-script = Script to run after stopping the display server (runs as root)
# greeter-setup-script = Script to run when starting a greeter (runs as root)
# session-setup-script = Script to run when starting a user session (runs as root)
# session-cleanup-script = Script to run when quitting a user session (runs as root)
autologin-guest=false
autologin-user=live
autologin-user-timeout=0
# autologin-session = Session to load for automatic login (overrides user-session)
# autologin-in-background = True if autologin session should not be immediately activated
# exit-on-failure = True if the daemon should exit if this seat fails
#
[Seat:*]
#type=local
#pam-service=lightdm
#pam-autologin-service=lightdm-autologin
#pam-greeter-service=lightdm-greeter
#xserver-command=X
#xmir-command=Xmir
#xserver-config=
#xserver-layout=
#xserver-allow-tcp=false
#xserver-share=true
#xserver-hostname=
#xserver-display-number=
#xdmcp-manager=
#xdmcp-port=177
#xdmcp-key=
#greeter-session=example-gtk-gnome
#greeter-hide-users=false
#greeter-allow-guest=true
#greeter-show-manual-login=false
#greeter-show-remote-login=true
#user-session=default
#allow-user-switching=true
#allow-guest=true
#guest-session=
#session-wrapper=lightdm-session
#greeter-wrapper=
#guest-wrapper=
#display-setup-script=
#display-stopped-script=
#greeter-setup-script=
#session-setup-script=
#session-cleanup-script=
#autologin-guest=false
#autologin-user=
#autologin-user-timeout=0
#autologin-in-background=false
#autologin-session=
#exit-on-failure=false

#
# XDMCP Server configuration
#
# enabled = True if XDMCP connections should be allowed
# port = UDP/IP port to listen for connections on
# listen-address = Host/address to listen for XDMCP connections (use all addresses if not present)
# key = Authentication key to use for XDM-AUTHENTICATION-1 or blank to not use authentication (stored in keys.conf)
# hostname = Hostname to report to XDMCP clients (defaults to system hostname if unset)
#
# The authentication key is a 56 bit DES key specified in hex as 0xnnnnnnnnnnnnnn.  Alternatively
# it can be a word and the first 7 characters are used as the key.
#
[XDMCPServer]
#enabled=false
#port=177
#listen-address=
#key=
#hostname=

#
# VNC Server configuration
#
# enabled = True if VNC connections should be allowed
# command = Command to run Xvnc server with
# port = TCP/IP port to listen for connections on
# listen-address = Host/address to listen for VNC connections (use all addresses if not present)
# width = Width of display to use
# height = Height of display to use
# depth = Color depth of display to use
#
[VNCServer]
#enabled=false
#command=Xvnc
#port=5900
#listen-address=
#width=1024
#height=768
#depth=8
HEREDOC
	
	cat > CHROOT/etc/hosts << HEREDOC
		127.0.0.1 localhost
		127.0.1.1 $(cat /etc/hostname)

		# The following lines are desirable for IPv6 capable hosts
		::1     localhost ip6-localhost ip6-loopback
		ff02::1 ip6-allnodes
		ff02::2 ip6-allrouters
HEREDOC
	
	echo "Installing packages..."
	
	chroot CHROOT/ /bin/bash <<EOT
		export DEBIAN_FRONTEND=noninteractive
		
		dpkg --add-architecture i386
		
		apt update
		
		apt install $PACKAGES $PACKAGES64 -y
		
		tasksel install $TASKSEL
EOT
	
	echo "Done"
	
	echo "Creating ISO"

	rm ISO

	mkdir ISO
	mkdir ISO/live
	mkdir ISO/boot
	mkdir ISO/boot/grub

	echo "Copying resources"

	cp -r IRESOURCES/* ISO/

	echo "Done"

	cat > ISO/boot/grub/grub.cfg <<EOT
insmod all_video
insmod efi_gop
insmod efi_uga
insmod ieee1275_fb
insmod vbe
insmod vga
insmod video_bochs
insmod video_cirrus
set gfxpayload=keep
insmod probe
insmod squash4
insmod ext2
insmod png

loopback loop /live/filesystem.squashfs

loadfont (loop)/usr/share/grub/unicode.pf2
insmod gettext

set gfxmode=auto
insmod gfxterm

terminal_output gfxterm

set default="1"

if background_image /grub.png; then
  set color_normal=white/black
  set color_highlight=black/white
else
  set menu_color_normal=cyan/blue
  set menu_color_highlight=white/blue
fi

menuentry "Installation media:" {
    echo
}

menuentry "- Install HeyTux" {
    echo "Please wait..."
	linux /boot/vmlinuz boot=live quiet splash
	initrd /boot/initrd.img
}

menuentry "Power:" {
    echo
}

menuentry "- Reboot" {
	reboot
}

menuentry "- Shutdown" {
	halt
}

menuentry "---" {
    echo
}

menuentry "UP and DOWN keys move the cursor." {
    echo
}

menuentry "ENTER or RETURN to continue." {
    echo
}
EOT

	umount "CHROOT/dev" -l
	umount "CHROOT/dev/pts" -l
	umount "CHROOT/proc" -l
	umount "CHROOT/sys" -l

	rm ISO/live/filesystem.squashfs

	sudo mksquashfs CHROOT/* ISO/live/filesystem.squashfs -noappend -e boot -Xbcj x86
	
	cp CHROOT/vmlinuz ISO/boot/vmlinuz
	cp CHROOT/initrd.img ISO/boot/initrd.img
	cp -r CHROOT/boot/efi ISO/boot/efi

	grub-mkrescue ISO/ -o live.iso
	
	echo "Done"
	
	trap - SIGINT SIGTERM SIGHUP EXIT
	
	notify-send "Build completed" "See output for more details"

elif [ "$TARCH" = "i386" ]; then
	echo "Not yet implemented."
fi
