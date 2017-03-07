#!/bin/sh -e
#
# Copyright (c) 2013-2017 Robert Nelson <robertcnelson@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

#Based off:
#https://github.com/beagleboard/meta-beagleboard/blob/master/meta-beagleboard-extras/recipes-support/usb-gadget/gadget-init/g-ether-load.sh

if [ -f /etc/rcn-ee.conf ] ; then
	. /etc/rcn-ee.conf
fi

log="am335x_evm:"

usb_gadget="/sys/kernel/config/usb_gadget"

#  idVendor           0x1d6b Linux Foundation
#  idProduct          0x0104 Multifunction Composite Gadget
#  bcdDevice            4.04
#  bcdUSB               2.00

usb_idVendor="0x1d6b"
usb_idProduct="0x0104"
usb_bcdDevice="0x0404"
usb_bcdUSB="0x0200"
usb_serialnr="000000"
usb_product="USB Device"

#usb0 mass_storage
usb_ms_cdrom=0
usb_ms_ro=1
usb_ms_stall=0
usb_ms_removable=1
usb_ms_nofua=1

#legacy support of: 2014-05-14
if [ "x${abi}" = "x" ] ; then
	eeprom="/sys/bus/i2c/devices/0-0050/eeprom"
	#taken care by the init flasher
	#Flash BeagleBone Black's eeprom:
	if [ -f /boot/uboot/flash-eMMC.txt ] ; then
		eeprom_location=$(ls /sys/devices/ocp.*/44e0b000.i2c/i2c-0/0-0050/eeprom 2> /dev/null)
		eeprom_header=$(hexdump -e '8/1 "%c"' ${eeprom} -s 5 -n 3)
		if [ "x${eeprom_header}" = "x335" ] ; then
			echo "Valid EEPROM header found"
		else
			echo "Invalid EEPROM header detected"
			if [ -f /opt/scripts/device/bone/bbb-eeprom.dump ] ; then
				if [ ! "x${eeprom_location}" = "x" ] ; then
					echo "Adding header to EEPROM"
					dd if=/opt/scripts/device/bone/bbb-eeprom.dump of=${eeprom_location}
					sync
					#We have to reboot, to load eMMC cape
					reboot
					#We shouldnt hit this...
					exit
				fi
			fi
		fi
	fi
fi

cleanup_extra_docs () {
	#recovers 82MB of space
	if [ -d /var/cache/doc-beaglebonegreen-getting-started ] ; then
		echo "${log} Cleaning up: /var/cache/doc-beaglebonegreen-getting-started"
		rm -rf /var/cache/doc-beaglebonegreen-getting-started || true
	fi
	if [ -d /var/cache/doc-seeed-bbgw-getting-started ] ; then
		echo "${log} Cleaning up: /var/cache/doc-seeed-bbgw-getting-started"
		rm -rf /var/cache/doc-seeed-bbgw-getting-started || true
	fi
}

#original user:
usb_image_file="/var/local/usb_mass_storage.img"

#*.iso priority over *.img
if [ -f /var/local/bb_usb_mass_storage.iso ] ; then
	usb_image_file="/var/local/bb_usb_mass_storage.iso"
elif [ -f /var/local/bb_usb_mass_storage.img ] ; then
	usb_image_file="/var/local/bb_usb_mass_storage.img"
fi

unset dnsmasq_usb0_usb1

board=$(cat /proc/device-tree/model | sed "s/ /_/g" | tr -d '\000')
case "${board}" in
TI_AM335x_BeagleBone)
	has_wifi="disable"
	cleanup_extra_docs
	dnsmasq_usb0_usb1="enabled"
	;;
TI_AM335x_BeagleBone_Black)
	has_wifi="disable"
	cleanup_extra_docs
	dnsmasq_usb0_usb1="enabled"
	;;
TI_AM335x_BeagleBone_Black_Wireless)
	has_wifi="enable"
	#recovers 82MB of space
	cleanup_extra_docs
	;;
TI_AM335x_BeagleBone_Blue)
	has_wifi="enable"
	cleanup_extra_docs
	;;
TI_AM335x_BeagleBone_Green)
	has_wifi="disable"
	unset board_bbgw
	unset board_sbbe
	if [ -f /var/local/bbg_usb_mass_storage.iso ] ; then
		usb_image_file="/var/local/bbg_usb_mass_storage.iso"
	elif [ -f /var/local/bbg_usb_mass_storage.img ] ; then
		usb_image_file="/var/local/bbg_usb_mass_storage.img"
	fi
	;;
TI_AM335x_BeagleBone_Green_Wireless)
	board_bbgw="enable"
	has_wifi="enable"
	if [ -f /var/local/bbgw_usb_mass_storage.iso ] ; then
		usb_image_file="/var/local/bbgw_usb_mass_storage.iso"
	elif [ -f /var/local/bbgw_usb_mass_storage.img ] ; then
		usb_image_file="/var/local/bbgw_usb_mass_storage.img"
	fi
	;;
SanCloud_BeagleBone_Enhanced)
	board_sbbe="enable"
	has_wifi="enable"
	cleanup_extra_docs
	;;
*)
	has_wifi="disable"
	unset board_bbgw
	unset board_sbbe
	;;
esac

if [ ! "x${usb_image_file}" = "x" ] ; then
	echo "${log} usb_image_file=[`readlink -f ${usb_image_file}`]"
fi

usb_iserialnumber="1234BBBK5678"
ISBLACK=""
ISGREEN=""
usb_iproduct="am335x_evm"
usb_imanufacturer="BeagleBoard.org"
wifi_prefix="BeagleBone"

#pre nvmem...
eeprom="/sys/bus/i2c/devices/0-0050/eeprom"
if [ -f ${eeprom} ] ; then
	usb_iserialnumber=$(hexdump -e '8/1 "%c"' ${eeprom} -n 28 | cut -b 17-28)
	ISBLACK=$(hexdump -e '8/1 "%c"' ${eeprom} -n 12 | cut -b 9-12)
	ISGREEN=$(hexdump -e '8/1 "%c"' ${eeprom} -n 19 | cut -b 17-19)
	ISBLACKVARIENT=$(hexdump -e '8/1 "%c"' ${eeprom} -n 16 | cut -b 13-16)
fi

#[PATCH (pre v8) 0/9] Add simple NVMEM Framework via regmap.
eeprom="/sys/class/nvmem/at24-0/nvmem"
if [ -f ${eeprom} ] ; then
	usb_iserialnumber=$(hexdump -e '8/1 "%c"' ${eeprom} -n 28 | cut -b 17-28)
	ISBLACK=$(hexdump -e '8/1 "%c"' ${eeprom} -n 12 | cut -b 9-12)
	ISGREEN=$(hexdump -e '8/1 "%c"' ${eeprom} -n 19 | cut -b 17-19)
	ISBLACKVARIENT=$(hexdump -e '8/1 "%c"' ${eeprom} -n 16 | cut -b 13-16)
fi

#[PATCH v8 0/9] Add simple NVMEM Framework via regmap.
eeprom="/sys/bus/nvmem/devices/at24-0/nvmem"
if [ -f ${eeprom} ] ; then
	usb_iserialnumber=$(hexdump -e '8/1 "%c"' ${eeprom} -n 28 | cut -b 17-28)
	ISBLACK=$(hexdump -e '8/1 "%c"' ${eeprom} -n 12 | cut -b 9-12)
	ISGREEN=$(hexdump -e '8/1 "%c"' ${eeprom} -n 19 | cut -b 17-19)
	ISBLACKVARIENT=$(hexdump -e '8/1 "%c"' ${eeprom} -n 16 | cut -b 13-16)
fi

usb_iproduct="BeagleBone"
if [ "x${ISBLACK}" = "xBBBK" ] || [ "x${ISBLACK}" = "xBNLT" ] ; then
	if [ "x${ISGREEN}" = "xBBG" ] ; then
		usb_imanufacturer="Seeed"
		usb_iproduct="BeagleBoneGreen"
	else
		#FIXME: should be a case statement, on the next varient..
		if [ "x${ISBLACKVARIENT}" = "xGW1A" ] ; then
			usb_imanufacturer="Seeed"
			usb_iproduct="BeagleBoneGreenWireless"
		else
			if [ "x$board_sbbe" = "xenable" ] ; then
				usb_imanufacturer="SanCloud"
				usb_iproduct="BeagleBoneEnhanced"
			else
				usb_iproduct="BeagleBoneBlack"
			fi
		fi
	fi
fi

mac_address="/proc/device-tree/ocp/ethernet@4a100000/slave@4a100200/mac-address"
if [ -f ${mac_address} ] ; then
	cpsw_0_mac=$(hexdump -v -e '1/1 "%02X" ":"' ${mac_address} | sed 's/.$//')
else
	#todo: generate random mac... (this is a development tre board in the lab...)
	cpsw_0_mac="1c:ba:8c:a2:ed:68"
fi

if [ -f /var/lib/connman/settings ] ; then
	wifi_name=$(grep Tethering.Identifier= /var/lib/connman/settings | awk -F '=' '{print $2}' || true)

	#Dont blindly, change Tethering.Identifier as user may have changed it, just match ${wifi_prefix}
	if [ "x${wifi_name}" = "x${wifi_prefix}" ] ; then
		ssid_append=$(echo ${cpsw_0_mac} | cut -b 13-17 | sed 's/://g' || true)
		if [ ! "x${wifi_name}" = "x${wifi_prefix}-${ssid_append}" ] ; then
			if [ ! "x${wifi_name}" = "x${wifi_prefix}-${ssid_append}" ] ; then
				systemctl stop connman.service || true
				sed -i -e 's:Tethering.Identifier='$wifi_name':Tethering.Identifier='$wifi_prefix'-'$ssid_append':g' /var/lib/connman/settings
				systemctl daemon-reload || true
				systemctl restart connman.service || true
			fi
		fi
	fi

	if [ -f /etc/systemd/system/network-online.target.wants/connman-wait-online.service ] ; then
		systemctl disable connman-wait-online.service || true
	fi
fi

mac_address="/proc/device-tree/ocp/ethernet@4a100000/slave@4a100300/mac-address"
if [ -f ${mac_address} ] ; then
	cpsw_1_mac=$(hexdump -v -e '1/1 "%02X" ":"' ${mac_address} | sed 's/.$//')
else
	#todo: generate random mac...
	cpsw_1_mac="1c:ba:8c:a2:ed:70"
fi

#Some devices are showing a blank cpsw_1_mac [00:00:00:00:00:00], let's fix that up...
if [ "x${cpsw_1_mac}" = "x00:00:00:00:00:00" ] ; then
	if [ -f /usr/bin/bc ] ; then
		mac_0_prefix=$(echo ${cpsw_0_mac} | cut -c 1-14)

		cpsw_0_6=$(echo ${cpsw_0_mac} | awk -F ':' '{print $6}')
		#bc cuts off leading zero's, we need ten/ones value
		cpsw_res=$(echo "obase=16;ibase=16;$cpsw_0_6 + 102" | bc)

		cpsw_1_mac=${mac_0_prefix}:$(echo ${cpsw_res} | cut -c 2-3)
	else
		cpsw_1_mac="1c:ba:8c:a2:ed:70"
	fi
fi

#Determine cpsw_2_mac assumed to be allocated between cpsw_0_mac and cpsw_1_mac
if [ -f /usr/bin/bc ] ; then
	mac_0_prefix=$(echo ${cpsw_0_mac} | cut -c 1-14)

	cpsw_0_6=$(echo ${cpsw_0_mac} | awk -F ':' '{print $6}')
	cpsw_1_6=$(echo ${cpsw_1_mac} | awk -F ':' '{print $6}')

	cpsw_add=$(echo "obase=16;ibase=16;$cpsw_0_6 + $cpsw_1_6" | bc)
	cpsw_div=$(echo "obase=16;ibase=16;$cpsw_add / 2" | bc)
	#bc cuts off leading zero's, we need ten/ones value
	cpsw_res=$(echo "obase=16;ibase=16;$cpsw_div + 100" | bc)

	cpsw_2_mac=${mac_0_prefix}:$(echo ${cpsw_res} | cut -c 2-3)
else
	cpsw_0_last=$(echo ${cpsw_0_mac} | awk -F ':' '{print $6}' | cut -c 2)
	cpsw_1_last=$(echo ${cpsw_1_mac} | awk -F ':' '{print $6}' | cut -c 2)
	mac_0_prefix=$(echo ${cpsw_0_mac} | cut -c 1-16)
	mac_1_prefix=$(echo ${cpsw_1_mac} | cut -c 1-16)
	#if cpsw_0_mac is even, add 1
	case "x${cpsw_0_last}" in
	x0)
		cpsw_2_mac="${mac_0_prefix}1"
		;;
	x2)
		cpsw_2_mac="${mac_0_prefix}3"
		;;
	x4)
		cpsw_2_mac="${mac_0_prefix}5"
		;;
	x6)
		cpsw_2_mac="${mac_0_prefix}7"
		;;
	x8)
		cpsw_2_mac="${mac_0_prefix}9"
		;;
	xA)
		cpsw_2_mac="${mac_0_prefix}B"
		;;
	xC)
		cpsw_2_mac="${mac_0_prefix}D"
		;;
	xE)
		cpsw_2_mac="${mac_0_prefix}F"
		;;
	*)
		#else, subtract 1 from cpsw_1_mac
		case "x${cpsw_1_last}" in
		xF)
			cpsw_2_mac="${mac_1_prefix}E"
			;;
		xD)
			cpsw_2_mac="${mac_1_prefix}C"
			;;
		xB)
			cpsw_2_mac="${mac_1_prefix}A"
			;;
		x9)
			cpsw_2_mac="${mac_1_prefix}8"
			;;
		x7)
			cpsw_2_mac="${mac_1_prefix}6"
			;;
		x5)
			cpsw_2_mac="${mac_1_prefix}4"
			;;
		x3)
			cpsw_2_mac="${mac_1_prefix}2"
			;;
		x1)
			cpsw_2_mac="${mac_1_prefix}0"
			;;
		*)
			#todo: generate random mac...
			cpsw_2_mac="1c:ba:8c:a2:ed:6a"
			;;
		esac
		;;
	esac
fi

#Create cpsw_3_mac, we need this for wl18xx access point's...
if [ -f /usr/bin/bc ] ; then
	mac_0_prefix=$(echo ${cpsw_0_mac} | cut -c 1-14)

	cpsw_0_6=$(echo ${cpsw_0_mac} | awk -F ':' '{print $6}')
	#bc cuts off leading zero's, we need ten/ones value
	cpsw_res=$(echo "obase=16;ibase=16;$cpsw_0_6 + 103" | bc)

	cpsw_3_mac=${mac_0_prefix}:$(echo ${cpsw_res} | cut -c 2-3)
else
	cpsw_3_mac="1c:ba:8c:a2:ed:71"
fi

#Create cpsw_4_mac, we need this for usb1 (BeagleBone Side)...
if [ -f /usr/bin/bc ] ; then
	mac_0_prefix=$(echo ${cpsw_0_mac} | cut -c 1-14)

	cpsw_0_6=$(echo ${cpsw_0_mac} | awk -F ':' '{print $6}')
	#bc cuts off leading zero's, we need ten/ones value
	cpsw_res=$(echo "obase=16;ibase=16;$cpsw_0_6 + 104" | bc)

	cpsw_4_mac=${mac_0_prefix}:$(echo ${cpsw_res} | cut -c 2-3)
else
	cpsw_4_mac="1c:ba:8c:a2:ed:72"
fi

#Create cpsw_5_mac, we need this for usb1 (USB host, pc side)...
if [ -f /usr/bin/bc ] ; then
	mac_0_prefix=$(echo ${cpsw_0_mac} | cut -c 1-14)

	cpsw_0_6=$(echo ${cpsw_0_mac} | awk -F ':' '{print $6}')
	#bc cuts off leading zero's, we need ten/ones value
	cpsw_res=$(echo "obase=16;ibase=16;$cpsw_0_6 + 105" | bc)

	cpsw_5_mac=${mac_0_prefix}:$(echo ${cpsw_res} | cut -c 2-3)
else
	cpsw_5_mac="1c:ba:8c:a2:ed:73"
fi

#mac address:
#cpsw_0_mac = eth0 - wlan0 (in eeprom)
#cpsw_1_mac = usb0 (BeagleBone Side) (in eeprom)
#cpsw_2_mac = usb0 (USB host, pc side) ((cpsw_0_mac + cpsw_2_mac) /2 )
#cpsw_3_mac = wl18xx (AP) (cpsw_0_mac + 3)
#cpsw_4_mac = usb1 (BeagleBone Side)
#cpsw_5_mac = usb1 (USB host, pc side)

echo "${log} cpsw_0_mac: [${cpsw_0_mac}]"
echo "${log} cpsw_1_mac: [${cpsw_1_mac}]"
echo "${log} cpsw_2_mac: [${cpsw_2_mac}]"
echo "${log} cpsw_3_mac: [${cpsw_3_mac}]"
echo "${log} cpsw_4_mac: [${cpsw_4_mac}]"
echo "${log} cpsw_5_mac: [${cpsw_5_mac}]"

#Save these to /etc/* so we don't have to recalculate again...
echo "${cpsw_0_mac}" > /etc/cpsw_0_mac || true
echo "${cpsw_1_mac}" > /etc/cpsw_1_mac || true
echo "${cpsw_2_mac}" > /etc/cpsw_2_mac || true
echo "${cpsw_3_mac}" > /etc/cpsw_3_mac || true
echo "${cpsw_4_mac}" > /etc/cpsw_4_mac || true
echo "${cpsw_5_mac}" > /etc/cpsw_5_mac || true

#udhcpd gets started at bootup, but we need to wait till g_multi is loaded, and we run it manually...
if [ -f /var/run/udhcpd.pid ] ; then
	echo "${log} [/etc/init.d/udhcpd stop]"
	/etc/init.d/udhcpd stop || true
fi

use_libcomposite () {
	echo "${log} use_libcomposite"
	unset has_img_file
	if [ -f ${usb_image_file} ] ; then
		actual_image_file=$(readlink -f ${usb_image_file} || true)
		if [ ! "x${actual_image_file}" = "x" ] ; then
			if [ -f ${actual_image_file} ] ; then
				has_img_file="true"
				test_usb_image_file=$(echo ${actual_image_file} | grep .iso || true)
				if [ ! "x${test_usb_image_file}" = "x" ] ; then
					usb_ms_cdrom=1
				fi
			else
				echo "${log} FIXME: no usb_image_file"
			fi
		else
			echo "${log} FIXME: no usb_image_file"
		fi
	else
		#We don't use a physical partition anymore...
		unset root_drive
		root_drive="$(cat /proc/cmdline | sed 's/ /\n/g' | grep root=UUID= | awk -F 'root=' '{print $2}' || true)"
		if [ ! "x${root_drive}" = "x" ] ; then
			root_drive="$(/sbin/findfs ${root_drive} || true)"
		else
			root_drive="$(cat /proc/cmdline | sed 's/ /\n/g' | grep root= | awk -F 'root=' '{print $2}' || true)"
		fi

		if [ "x${root_drive}" = "x/dev/mmcblk0p1" ] || [ "x${root_drive}" = "x/dev/mmcblk1p1" ] ; then
			echo "${log} FIXME: no valid drive to share over usb"
		else
			actual_image_file="${root_drive%?}1"
		fi
	fi
	echo "${log} modprobe libcomposite"
	modprobe libcomposite || true
	if [ -d /sys/module/libcomposite ] ; then
		if [ -d ${usb_gadget} ] ; then
			if [ ! -d ${usb_gadget}/g_multi/ ] ; then
				echo "${log} Creating g_multi"
				mkdir -p ${usb_gadget}/g_multi || true
				cd ${usb_gadget}/g_multi

				echo ${usb_bcdUSB} > bcdUSB
				echo ${usb_idVendor} > idVendor # Linux Foundation
				echo ${usb_idProduct} > idProduct # Multifunction Composite Gadget
				echo ${usb_bcdDevice} > bcdDevice

				#0x409 = english strings...
				mkdir -p strings/0x409

				echo ${usb_iserialnumber} > strings/0x409/serialnumber
				echo ${usb_imanufacturer} > strings/0x409/manufacturer
				echo ${usb_iproduct} > strings/0x409/product

				mkdir -p functions/rndis.usb0
				# first byte of address must be even
				echo ${cpsw_2_mac} > functions/rndis.usb0/host_addr
				echo ${cpsw_1_mac} > functions/rndis.usb0/dev_addr

				mkdir -p functions/ecm.usb0
				echo ${cpsw_4_mac} > functions/ecm.usb0/host_addr
				echo ${cpsw_5_mac} > functions/ecm.usb0/dev_addr

				mkdir -p functions/acm.usb0

				if [ "x${has_img_file}" = "xtrue" ] ; then
					mkdir -p functions/mass_storage.usb0
					echo ${usb_ms_stall} > functions/mass_storage.usb0/stall
					echo ${usb_ms_cdrom} > functions/mass_storage.usb0/lun.0/cdrom
					echo ${usb_ms_nofua} > functions/mass_storage.usb0/lun.0/nofua
					echo ${usb_ms_removable} > functions/mass_storage.usb0/lun.0/removable
					echo ${usb_ms_ro} > functions/mass_storage.usb0/lun.0/ro
					echo ${actual_image_file} > functions/mass_storage.usb0/lun.0/file
				fi

				mkdir -p configs/c.1/strings/0x409
				echo "Multifunction with RNDIS" > configs/c.1/strings/0x409/configuration

				echo 500 > configs/c.1/MaxPower

				ln -s functions/rndis.usb0 configs/c.1/
				ln -s functions/ecm.usb0 configs/c.1/
				ln -s functions/acm.usb0 configs/c.1/
				if [ "x${has_img_file}" = "xtrue" ] ; then
					ln -s functions/mass_storage.usb0 configs/c.1/
				fi

#FIXME, needs more testing in Windows 7 & 10, as the inteface doesn't show up (no usb flash, serial, ethernet)
#				# If Linux sees a device with RNDIS as the first
#				# interface and there is a second configuration,
#				# it will prefer the second configuration. OS X
#				# used to do the same, but it was broken in 10.11
#				# which is why we have to include the ecm in the
#				# first configuration (c.1). So, c.1 will be used
#				# on Windows and macOS >= 10.11 and c.2 will be
#				# used on Linux and macOS <= 10.10
#				mkdir -p configs/c.2/strings/0x409
#				echo "Multifunction without RNDIS" > configs/c.2/strings/0x409/configuration
#
#				echo 500 > configs/c.2/MaxPower
#
#				ln -s functions/ecm.usb0 configs/c.2/
#				ln -s functions/acm.usb0 configs/c.2/
#				if [ "x${has_img_file}" = "xtrue" ] ; then
#					ln -s functions/mass_storage.usb0 configs/c.2/
#				fi

				#ls /sys/class/udc
				echo musb-hdrc.0.auto > UDC
				usb0="enable"
				usb1="enable"
				echo "${log} g_multi Created"
			else
				echo "${log} FIXME: need to bring down g_multi first, before running a second time."
			fi
		else
			echo "${log} ERROR: no [${usb_gadget}]"
		fi
	else
		echo "${log} ERROR: [libcomposite didn't load]"
	fi
}

g_network="iSerialNumber=${usb_iserialnumber} iManufacturer=${usb_imanufacturer} iProduct=${usb_iproduct} host_addr=${cpsw_2_mac} dev_addr=${cpsw_1_mac}"

usb0_fail () {
	unset usb0
	modprobe g_serial || true
}

#update_initrd () {
#	if [ ! -f /boot/initrd.img-$(uname -r) ] ; then
#		update-initramfs -c -k $(uname -r)
#	else
#		update-initramfs -u -k $(uname -r)
#	fi
#}

g_multi_retry () {
	echo "info: [modprobe g_multi ${g_multi_options}] failed"
#	update_initrd
	modprobe g_multi ${g_multi_options} || usb0_fail
}

g_ether_retry () {
	echo "info: [modprobe g_ether ${g_network}] failed"
#	update_initrd
	modprobe g_ether ${g_network} || usb0_fail
}

g_serial_retry () {
	echo "info: [modprobe g_serial] failed"
#	update_initrd
	modprobe g_serial || true
}

use_old_g_multi () {
	echo "${log} use_old_g_multi"
	#priorty:
	#g_multi
	#g_ether
	#g_serial

	#g_multi: Do we have image file?
	if [ -f ${usb_image_file} ] ; then
		test_usb_image_file=$(echo ${usb_image_file} | grep .iso || true)
		if [ ! "x${test_usb_image_file}" = "x" ] ; then
			usb_ms_cdrom=1
		fi
		g_multi_options="file=${usb_image_file} cdrom=${usb_ms_cdrom} ro=${usb_ms_ro}"
		g_multi_options="${g_multi_options} stall=${usb_ms_stall} removable=${usb_ms_removable}"
		g_multi_options="${g_multi_options} nofua=${usb_ms_nofua} ${g_network}}"
		modprobe g_multi ${g_multi_options} || g_multi_retry
		usb0="enable"
	else
		#g_multi: Do we have a non-rootfs "fat" partition?
		unset root_drive
		root_drive="$(cat /proc/cmdline | sed 's/ /\n/g' | grep root=UUID= | awk -F 'root=' '{print $2}' || true)"
		if [ ! "x${root_drive}" = "x" ] ; then
			root_drive="$(/sbin/findfs ${root_drive} || true)"
		else
			root_drive="$(cat /proc/cmdline | sed 's/ /\n/g' | grep root= | awk -F 'root=' '{print $2}' || true)"
		fi

		if [ "x${root_drive}" = "x/dev/mmcblk0p1" ] || [ "x${root_drive}" = "x/dev/mmcblk1p1" ] ; then
			#g_ether: Do we have udhcpd/dnsmasq?
			if [ -f /usr/sbin/udhcpd ] || [ -f /usr/sbin/dnsmasq ] ; then
				modprobe g_ether ${g_network} || g_ether_retry
				usb0="enable"
			else
				#g_serial: As a last resort...
				modprobe g_serial || g_serial_retry
			fi
		else
			boot_drive="${root_drive%?}1"
			modprobe g_multi file=${boot_drive} cdrom=0 ro=0 stall=0 removable=1 nofua=1 ${g_network} || true
			usb0="enable"
		fi
	fi
}

unset usb0 usb1

#use libcomposite with v4.4.x+ kernel's...
kernel_major=$(uname -r | cut -d. -f1 || true)
kernel_minor=$(uname -r | cut -d. -f2 || true)
compare_major="4"
compare_minor="4"

if [ "${kernel_major}" -lt "${compare_major}" ] ; then
	use_old_g_multi
elif [ "${kernel_major}" -eq "${compare_major}" ] ; then
	if [ "${kernel_minor}" -lt "${compare_minor}" ] ; then
		use_old_g_multi
	else
		use_libcomposite
	fi
else
	use_libcomposite
fi

if [ "x${usb0}" = "xenable" ] ; then
	echo "${log} Starting usb0 network"
	# Auto-configuring the usb0 network interface:
	$(dirname $0)/autoconfigure_usb0.sh || true
fi

if [ "x${usb1}" = "xenable" ] ; then
	echo "${log} Starting usb1 network"
	# Auto-configuring the usb1 network interface:
	$(dirname $0)/autoconfigure_usb1.sh || true
fi

	dnsmasq_usb0_usb1="enabled"

if [ "x${dnsmasq_usb0_usb1}" = "xenabled" ] ; then
	if [ -d /sys/kernel/config/usb_gadget ] ; then
		/etc/init.d/udhcpd stop || true

		wfile="/etc/dnsmasq.d/SoftAp0"
		echo "interface=usb0" >> ${wfile}
		echo "interface=usb1" >> ${wfile}
		echo "port=53" >> ${wfile}
		echo "dhcp-authoritative" >> ${wfile}
		echo "domain-needed" >> ${wfile}
		echo "bogus-priv" >> ${wfile}
		echo "expand-hosts" >> ${wfile}
		echo "cache-size=2048" >> ${wfile}
		echo "dhcp-range=usb0,192.168.7.1,192.168.7.1,2m" >> ${wfile}
		echo "dhcp-range=usb1,192.168.6.1,192.168.6.1,2m" >> ${wfile}
		echo "listen-address=127.0.0.1" >> ${wfile}
		echo "listen-address=192.168.7.2" >> ${wfile}
		echo "listen-address=192.168.6.2" >> ${wfile}
		echo "dhcp-option=usb0,3" >> ${wfile}
		echo "dhcp-option=usb0,6" >> ${wfile}
		echo "dhcp-option=usb1,3" >> ${wfile}
		echo "dhcp-option=usb1,6" >> ${wfile}
		echo "address=/#/172.1.8.1" >> ${wfile}

		systemctl restart dnsmasq || true
	fi
fi

if [ -d /sys/class/tty/ttyGS0/ ] ; then
	echo "${log} Starting serial-getty@ttyGS0.service"
	systemctl start serial-getty@ttyGS0.service || true
fi

#create_ap is now legacy, use connman...
if [ -f /usr/bin/create_ap ] ; then
	if [ "x${has_wifi}" = "xenable" ] ; then
		ifconfig wlan0 down
		ifconfig wlan0 hw ether ${cpsw_0_mac}
		ifconfig wlan0 up || true
		echo "${cpsw_0_mac}" > /etc/wlan0-mac
		systemctl start create_ap &
	fi
fi

#Just Cleanup /etc/issue, systemd starts up tty before these are updated...
sed -i -e '/Address/d' /etc/issue || true

#legacy support of: 2014-05-14
if [ "x${abi}" = "x" ] ; then
	#taken care by the init flasher
	if [ -f /boot/uboot/flash-eMMC.txt ] ; then
		if [ ! -d /boot/uboot/debug/ ] ; then
			mkdir -p /boot/uboot/debug/ || true
		fi

		if [ -f /opt/scripts/tools/beaglebone-black-eMMC-flasher.sh ] ; then
			/bin/bash /opt/scripts/tools/beaglebone-black-eMMC-flasher.sh >/boot/uboot/debug/flash-eMMC.log 2>&1
		fi
	fi
fi

#legacy support of: 2014-05-14
if [ "x${abi}" = "x" ] ; then
	#Taken care by:
	#https://github.com/RobertCNelson/omap-image-builder/blob/master/target/init_scripts/generic-debian.sh#L51
	if [ -f /resizerootfs ] ; then
		if [ ! -d /boot/debug/ ] ; then
			mkdir -p /boot/debug/ || true
		fi

		drive=$(cat /resizerootfs)
		if [ "x${drive}" = "x" ] ; then
			drive="/dev/mmcblk0"
		fi

		#FIXME: only good for two partition "/dev/mmcblkXp2" setups...
		resize2fs ${drive}p2 >/boot/debug/resize.log 2>&1
		rm -rf /resizerootfs || true
	fi
fi

unset enable_cape_universal
enable_cape_universal=$(grep 'cape_universal=enable' /proc/cmdline || true)
if [ ! "x${enable_cape_universal}" = "x" ] ; then
	#loading cape-universal...
	if [ -f /sys/devices/platform/bone_capemgr/slots ] ; then

		#cape-universal Exports all pins not used by HDMIN and eMMC (including audio)
		#cape-universaln Exports all pins not used by HDMI and eMMC (no audio pins are exported)
		#cape-univ-emmc Exports pins used by eMMC, load if eMMC is disabled
		#cape-univ-hdmi Exports pins used by HDMI video, load if HDMI is disabled
		#cape-univ-audio Exports pins used by HDMI audio

		unset stop_cape_load
		#Make sure bone_capemgr.uboot_capemgr_enabled=1 wasn't passed to cmdline...
		if [ "x${stop_cape_load}" = "x" ] ; then
			check_enable_partno=$(grep bone_capemgr.uboot_capemgr_enabled=1 /proc/cmdline || true)
			if [ ! "x${check_enable_partno}" = "x" ] ; then
				stop_cape_load="stop"
			fi
		fi

		#Make sure bone_capemgr.enable_partno wasn't passed to cmdline...
		if [ "x${stop_cape_load}" = "x" ] ; then
			check_enable_partno=$(grep bone_capemgr.enable_partno /proc/cmdline || true)
			if [ ! "x${check_enable_partno}" = "x" ] ; then
				stop_cape_load="stop"
			fi
		fi

		#Make sure no custom overlays are loaded...
		if [ "x${stop_cape_load}" = "x" ] ; then
			check_cape_loaded=$(cat /sys/devices/platform/bone_capemgr/slots | awk '{print $3}' | grep 0 | tail -1 || true)
			if [ ! "x${check_cape_loaded}" = "x" ] ; then
				stop_cape_load="stop"
			fi
		fi

		#Make sure we load the correct overlay based on lack/custom dtb's...
		if [ "x${stop_cape_load}" = "x" ] ; then
			unset overlay
			check_dtb=$(cat /boot/uEnv.txt | grep -v '#' | grep dtb | tail -1 | awk -F '=' '{print $2}' || true)
			if [ ! "x${check_dtb}" = "x" ] ; then
				case "${check_dtb}" in
				am335x-boneblack-overlay.dtb)
					overlay="univ-all"
					;;
				am335x-boneblack-emmc-overlay.dtb)
					overlay="univ-emmc"
					;;
				am335x-boneblack-hdmi-overlay.dtb)
					overlay="univ-hdmi"
					;;
				am335x-boneblack-nhdmi-overlay.dtb)
					overlay="univ-nhdmi"
					;;
				am335x-bonegreen-overlay.dtb)
					overlay="univ-all"
					;;
				esac
			else
				machine=$(cat /proc/device-tree/model | sed "s/ /_/g" | tr -d '\000')
				case "${machine}" in
				TI_AM335x_BeagleBone)
					overlay="univ-all"
					;;
				TI_AM335x_BeagleBone_Black_Wireless)
					overlay="cape-universaln"
					;;
				TI_AM335x_BeagleBone_Blue)
					unset overlay
					;;
				TI_AM335x_BeagleBone_Black)
					overlay="cape-universaln"
					;;
				TI_AM335x_BeagleBone_Green)
					overlay="univ-emmc"
					;;
				TI_AM335x_BeagleBone_Green_Wireless)
					if [ -f /usr/local/lib/node_modules/node-red-node-beaglebone/.bbgw-dont-load ] ; then
						unset overlay
					else
						overlay="univ-bbgw"
					fi
					;;
				esac
			fi
			if [ ! "x${overlay}" = "x" ] ; then
				dtbo="${overlay}-00A0.dtbo"
				if [ -f /lib/firmware/${dtbo} ] ; then
					if [ -f /usr/local/bin/config-pin ] ; then
						config-pin overlay ${overlay} || true
					fi
				fi
			fi
		fi
	fi
fi
#
