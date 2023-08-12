#!/bin/sh
# Skripta za skidanje odredjenih programa i mojih konfiguracionih file-ova

###   Variables   ###
dotfiles="https://github.com/AleksaSremski/dotfiles.git"
Ipkgs=(curl git ntp base-devel)
export TERM=ansi

###   Functions   ###
installpackage() {
	pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

removepackage() {
	pacman --noconfirm -R "$1" >/dev/null 2>&1
}

error() {
	whiptail --title "Error!" --msgbox "$1" 15 60
	exit 1
}

pacmansync() {
	whiptail --infobox "Checking if your system is up to date..." 15 70
	cp programs /tmp/
	pacman --noconfirm -Syy >/dev/null 2>&1
	refresh_keys
	pacman --noconfirm -Syu >/dev/null 2>&1
}

installAURpackage() {
	whiptail --title "Installation!" \
		--infobox "Program \"$program\" is being installed. ($n:$total)\n$program: $desc." 15 70
	sudo -u $username yay --noconfirm -S "$1" >/dev/null 2>&1
}

welcomemsg() {
# First message
	whiptail --title "Welcome!" --yes-button "Ok" \
		--no-button "Return..." \
		--yesno "This is script for installing my desktop enviroment 'DE' with my configurational files.\nIt's basically copy of Luke Smiths build of 'DE' with my personal configuration files.\n\n-Aleksa" 15 60 || {
		clear
		exit 1
	}

	whiptail --title "Important Note!" --yes-button "All ready!" \
		--no-button "Return..." \
		--yesno "Be sure the computer you are using has current pacman updates and refreshed Arch keyrings.\\n\\nIf it does not, the installation of some programs might fail." 8 70 || {
		clear
		exit 1
	}
 }

preinstallmsg() {
# Ask if you want to proceed with installation or exit
	whiptail --title "Lets get started!" --yes-button "Yes, I agree." \
		--no-button "No, exit script." \
		--yesno "From this point whole script is goint to be automated, so if you want to exit now is the time.\nIf you want to continue script will create new user and install my 'DE'." 15 70 || {
		clear
		exit 1
	}
}

refresh_keys() {
	pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
}

getuserandpass() {
# Get username
	username=$(whiptail --title "Lets start with creating new user!" --inputbox "Please enter your username:" 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo $username | grep -q "^[a-z_][a-z0-9_-]*$"; do
		username=$(whiptail --title "Oh no!" --inputbox "Please enter valid username, so not numbers, special characthers or upper case letters:" 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	done
# Get passwords
	pass1=$(whiptail --title "Lets add password to the new user" --passwordbox "Please type your password:" 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	pass2=$(whiptail --title "Lets add password to the new user" --passwordbox "Please retype your password:" 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
# In case passwords do not match
	while ! [ $pass1 = $pass2 ]; do
		pass1=$(whiptail --title "Passwords do not match!" --passwordbox "Please type again your password:" 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
		pass2=$(whiptail  --passwordbox "Please retype your password:" 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	done
}

usercheck() {
# Check if user already exists on the system and prompts user if he wants to proceed
	! { id -u "$username" >/dev/null 2>&1; } ||
		whiptail --title "WARNING" --yes-button "CONTINUE" \
			--no-button "No wait..." \
			--yesno "The user '$username' already exists on this system. The script can install DE for a said user but it will overwrite users password and configurational files [ note: user data won't be deleted ]." 14 70
}

adduserandpass() {
# Adds user
	whiptail  --infobox "User '$username' is being created" 7 50
	useradd -m -g wheel "$username" || #>/dev/null/ 2>&1 ||
		usermod -a -G wheel "$username" && mkdir -p /home/"$username" && chown "$username":wheel /home/"$username"
	echo "$username:$pass1" | chpasswd
	unset	pass1 pass2
	echo " %wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
	echo " Defaults !tty_tickets" >> /etc/sudoers
	mkdir /home/"$username"/.config && chown -R "$username":wheel /home/"$username"/.config
}

yayinstall() {
# Used only to install yay (which is needed to install other packages)
	whiptail --title "A few important things!" --infobox "Package \"$1\" is being installed." 12 60
	cd /home/"$username"/.config
	sudo -u "$username" git clone https://aur.archlinux.org/"$1".git >/dev/null 2>&1
	cd "$1"
	sudo -u "$username" makepkg --noconfirm -si >/dev/null 2>&1 || return 1
}

installpkg() {
# Installing packages with pacman
	whiptail --title "Installation!" \
	--infobox "Program \"$program\" is being installed. ($n:$total)\n$program: $desc." 15 70
	installpackage "$program"
}

maininstall() {
# Main installation loop
	n=0
	total=$(wc -l </tmp/programs)
	while read -r tag program desc; do
		n=$((n + 1))
		echo "$desc" | grep -q "^\".*\"$" &&
			desc="$(echo "$desc" | sed -E "s/(^\"|\"$)//g")"
		case "$tag" in
		"N") installpkg "$program" "$desc" ;;
		"A") installAURpackage "$program" "$desc" ;;
		"G") gitinstall "$program" "$desc" ;;
		esac
	done </tmp/programs
}

gitinstall() {
# Installation via git, used only to install st, dwm, dmenu and slstatus!
	whiptail --title "Installation!" \
	--infobox "Program \"$program\" is being installed. ($n:$total)\n$program: $desc." 15 70
	cd "/home/"$username"/.config/"
	sudo -u "$username" git clone https://github.com/AleksaSremski/"$program".git >/dev/null 2>&1
	cd "$program"
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp
}

deploydotfiles() {
# Deploys my configurational files
	whiptail --title "Configuration of programs!" \
	--infobox "Deploying my configurational files." 15 70
	cd "/tmp"
	git clone "$1" >/dev/null 2>&1
	cp -r dotfiles/.config/* /home/"$username"/.config/ && rm -rf dotfiles/.config/
	cp dotfiles/* /home/"$username"/ && chown -R "$username":wheel /home/"$username"/*
}

finalize() {
# Final message
	whiptail --title "Installation complete!" --msgbox "Installation has finished, you can login as new user.\n\nEnjoy!" 14 70
	clear
}

###   START   ###
# Pacman sync
pacmansync

# First Message
welcomemsg

# Pre installation message
preinstallmsg

# Gets user name and password
getuserandpass

# Checks if user already exists
usercheck

# Creates user (with password and joins it in wheel group)
adduserandpass

# Installing very Important packages Ipkgs=(curl git ntp base-devel)
 for x in ${Ipkgs[@]}; do
 	whiptail --title "A few important things!" --infobox "Package \"$x\" is being installed." 12 60
 	installpackage "$x"
 done

# Use all cores for compiling
sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

# Installs yay (which is needed to install other packages)
yayinstall "yay-bin"

# Synchronize time
whiptail --title "A few important things!" \
	--infobox "Synchronizing system time to ensure successful and secure installation of software..." 8 70
ntpd -q -g >/dev/null 2>&1

maininstall

# Deploy dotfiles
deploydotfiles "$dotfiles"

# Final Message
finalize

