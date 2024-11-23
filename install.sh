#!/usr/bin/env bash

# Based on https://github.com/IogaMaster/dotfiles/blob/29f554b1a90631423e66c3289f05cb7a249594bd/lib/deploy/default.nix

NIXOS_KEXEC_INSTALLER_VERSION="v2.1.0"

GET_CURRENT_ARCH_URL="https://raw.githubusercontent.com/moritztim/nixos-kexec-installer/refs/tags/$NIXOS_KEXEC_INSTALLER_VERSION/src/get_current_arch.sh"
NIXOS_KEXEC_INSTALLER_URL="https://github.com/moritztim/nixos-kexec-installer/releases/download/$NIXOS_KEXEC_INSTALLER_VERSION/nixos-kexec.sh"

echo "This script will remotely wipe the system \"$3\" and erect \"$1\" in its place. It will login as \"$2\" on \"$3\"."
echo "Are you sure you want to continue? [y/N]"
read -r response

if [ "$response" != "y" ]; then
		echo "Aborting."
		exit 1
fi

echo "Remotely obtaining architecture..."
architecture=$(ssh $2@$3 "curl -sSLf $GET_CURRENT_ARCH_URL | bash")
if [ -z "$architecture" ]; then
	echo "Failed to obtain architecture."
	exit 1
fi
echo "Architecture: $architecture"

echo "Remotely executing kexec installer image..."
ssh $2@$3 "sudo bash <(curl -sSLf $NIXOS_KEXEC_INSTALLER_URL) --install"

echo "Waiting for remote system to reboot..."
while true; do ping -c1 nixos > /dev/null && break; done

echo "Obtaining hardware configuration..."
ssh root@nixos 'nixos-generate-config --show-hardware-config --root /mnt' > hosts/$architecture/$1/hardware-configuration.nix

echo "Installing..."
nix run github:nix-community/nixos-anywhere -- --flake .#$1 root@nixos

echo "Done."
