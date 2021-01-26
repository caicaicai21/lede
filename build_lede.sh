#!/bin/bash

start_bulid() {
	#make download -j$(($(nproc) + 1))
	make download -j$1

	#make -j$(($(nproc) + 1)) V=s
	make -j$1 V=s
}

check_git(){
	if [ $? -ne 0 ];then
		echo "git download fail, exit..."
		exit 1
	fi
}

mtk_devices=(
mir3g
newifi3
hc5761
)

MTK_DRIVER=0
ONLY_CONFIG=0
MODEL=x86_64
THREADS=$(nproc)
SKIP=0
NATFLOW=0
BATMAN=0

while getopts :osnbMt:m: OPTION; do
	case $OPTION in
		o) ONLY_CONFIG=1
		;;
		M) MTK_DRIVER=1
		;;
		m) MODEL=$OPTARG
		;;
		n) #NATFLOW=1
			echo "natflow disable"
		;;
		b) BATMAN=1
		;;
		t)
			if [ $OPTARG -gt 0 ];then
				THREADS=$OPTARG
			fi
		;;
		s) SKIP=1
		;;
		?)
		printf "[Usage]
	-o: only create config file
	-M: use mtk wireless driver
	-b: include B.A.T.M.A.N-adv
	-n: use natflow (only mtk device)
	-t <NUMBER>: thread count, default cpu count
	-m <MODEL_NAME>: x86_64(default) rpi3 rpi4 mir3g newifi3 hc5761\n" >&2
		exit 1 ;;
	esac
done

if [ $SKIP -eq 1 ];then
	start_bulid ${THREADS}
	exit 0
fi

printf "Use MTK wireless drives: "
if [ $MTK_DRIVER -eq 1 ];then
	printf "yes\n"
else
	printf "no\n"
fi
printf "Only config: "
if [ $ONLY_CONFIG -eq 1 ];then
	printf "yes\n"
else
	printf "no\n"
fi
printf "Include B.A.T.M.A.N-adv: "
if [ $BATMAN -eq 1 ];then
	printf "yes\n"
else
	printf "no\n"
fi
if [[ ! "${mtk_devices[@]}" =~ "${MODEL}" ]];then
	NATFLOW=0
fi
printf "Use Natflow: "
if [ $NATFLOW -eq 1 ];then
	printf "yes\n"
else
	printf "no\n"
fi
echo "Model name: $MODEL"
echo "Thread count: $THREADS"

if [ -f ".config" ];then
	make clean
fi

#rm -rf ./package/lean/luci-theme-argon/
#rm -rf ./package/lean/luci-theme-netgear/

cd package
if [ ! -d "custom-packages" ];then
	mkdir custom-packages
fi
cd custom-packages

if [ -d "natflow" ];then
	rm -rf ./natflow/
fi
if [ -f "../../target/linux/ramips/patches-5.4/990-mtk-driver-hwnat-compat-with-natflow.patch" ];then
	rm -rf ../../target/linux/ramips/patches-5.4/990-mtk-driver-hwnat-compat-with-natflow.patch
fi
if [ $NATFLOW -eq 1 ];then
	git clone https://github.com/caicaicai21/natflow.git
	check_git
	mv ./natflow/990-mtk-driver-hwnat-compat-with-natflow.patch ../../target/linux/ramips/patches-5.4/990-mtk-driver-hwnat-compat-with-natflow.patch	
fi

#if [ ! -d "luci-theme-atmaterial" ];then
#    git clone https://github.com/openwrt-develop/luci-theme-atmaterial.git
#    check_git
#else
#    cd luci-theme-atmaterial
#    git pull
#    check_git
#    cd ..
#fi

#if [ -d "OpenClash" ];then
#    rm -rf ./OpenClash/
#fi
#git clone https://github.com/vernesong/OpenClash.git
#check_git

if [ -d "helloworld" ];then
	rm -rf ./helloworld/
fi
#git clone https://github.com/fw876/helloworld.git
git clone https://github.com/caicaicai21/helloworld.git
check_git

if [ -d "luci-app-smartdns" ];then
	rm -rf ./luci-app-smartdns/
fi
git clone -b lede https://github.com/pymumu/luci-app-smartdns.git
check_git
sed -i "s/include ..\/..\/luci.mk/include \$(TOPDIR)\/feeds\/luci\/luci.mk/" ./luci-app-smartdns/Makefile
sed -i "s/+luci-compat //" ./luci-app-smartdns/Makefile
sed -i "/^PKG_VERSION/i\PKG_NAME:=luci-app-smartdns" ./luci-app-smartdns/Makefile

if [ -d "smartdns" ];then
	rm -rf ./smartdns/
fi
git clone https://github.com/pymumu/smartdns.git
check_git
cp -rf ./smartdns/package/openwrt ./smartdns_tmp
rm -rf ./smartdns/
mv ./smartdns_tmp ./smartdns
#sed -i '/\tuci set dhcp.@dnsmasq\[0\].noresolv=1/d' ./smartdns/files/etc/init.d/smartdns

cd ../../

./scripts/feeds update -a
./scripts/feeds install -a

rm -f ./.config*
touch ./.config

# target cpu
if [ "$MODEL" = "x86_64" ];then
cat >> .config <<EOF
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_Generic=y
EOF
elif [ "$MODEL" = "rpi3" ];then
cat >> .config <<EOF
CONFIG_TARGET_brcm2708=y
CONFIG_TARGET_brcm2708_bcm2710=y
CONFIG_TARGET_brcm2708_bcm2710_DEVICE_rpi-3=y
EOF
elif [ "$MODEL" = "rpi4" ];then
cat >> .config <<EOF
CONFIG_TARGET_brcm2708=y
CONFIG_TARGET_brcm2708_bcm2711=y
CONFIG_TARGET_brcm2708_bcm2711_DEVICE_rpi-4=y
EOF
elif [ "$MODEL" = "mir3g" ];then
cat >> .config <<EOF
CONFIG_TARGET_ramips=y
CONFIG_TARGET_ramips_mt7621=y
CONFIG_TARGET_ramips_mt7621_DEVICE_xiaomi_mir3g=y
EOF
elif [ "$MODEL" = "newifi3" ];then
cat >> .config <<EOF
CONFIG_TARGET_ramips=y
CONFIG_TARGET_ramips_mt7621=y
CONFIG_TARGET_ramips_mt7621_DEVICE_d-team_newifi-d2=y
EOF
elif [ "$MODEL" = "hc5761" ];then
cat >> .config <<EOF
CONFIG_TARGET_ramips=y
CONFIG_TARGET_ramips_mt7620=y
CONFIG_TARGET_ramips_mt7620_DEVICE_hiwifi_hc5761=y
EOF
else
	echo "Build type error, use: x86_64, rpi3, rpi4, mir3g, newifi3, hc5761"
	exit -1
fi

# packages
if [ "$MODEL" = "x86_64" ];then
cat >> .config <<EOF
# CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-theme-netgear=y
# CONFIG_PACKAGE_luci-theme-atmaterial=y
#
CONFIG_PACKAGE_qemu-ga=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_nano=y
CONFIG_PACKAGE_wget=y
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_PACKAGE_ipv6helper=y
#
CONFIG_PACKAGE_luci-app-netdata=y
# CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_luci-app-softethervpn=y
CONFIG_PACKAGE_luci-app-vlmcsd=y
CONFIG_PACKAGE_luci-app-zerotier=y
CONFIG_PACKAGE_luci-app-ssr-plus=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Simple_obfs=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_V2ray_plugin=y
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_V2ray is not set
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Xray=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Trojan=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Redsocks2=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Kcptun=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_ShadowsocksR_Server=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_DNS2SOCKS=y
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_NaiveProxy is not set
CONFIG_PACKAGE_luci-app-smartdns=y
CONFIG_PACKAGE_luci-app-ddns=y
CONFIG_PACKAGE_luci-app-v2ray-server=y
CONFIG_PACKAGE_ddns-scripts_cloudflare.com-v4=y
#
CONFIG_TARGET_IMAGES_GZIP=y
# CONFIG_EFI_IMAGES is not set
# CONFIG_VDI_IMAGES is not set
# CONFIG_VMDK_IMAGES is not set
# # CONFIG_TARGET_IMAGES_PAD is not set
#
# CONFIG_PACKAGE_luci-app-openvpn-server is not set
# CONFIG_PACKAGE_luci-app-amule is not set
# CONFIG_PACKAGE_luci-app-music-remote-center is not set
# CONFIG_PACKAGE_luci-app-nlbwmon is not set
# CONFIG_PACKAGE_luci-app-airplay2 is not set
# CONFIG_PACKAGE_luci-app-adbyby-plus is not set
# CONFIG_PACKAGE_luci-app-qbittorrent is not set
# CONFIG_PACKAGE_luci-app-pptp-server is not set
# CONFIG_PACKAGE_luci-app-ipsec-vpnd is not set
# CONFIG_PACKAGE_autosamba is not set
# CONFIG_PACKAGE_luci-app-samba is not set
# CONFIG_PACKAGE_luci-app-vsftpd is not set
# CONFIG_PACKAGE_luci-app-xlnetacc is not set
# CONFIG_PACKAGE_luci-app-accesscontrol is not set
# CONFIG_PACKAGE_luci-app-sqm is not set
#
# CONFIG_PACKAGE_luci-app-unblockmusic is not set
# CONFIG_UnblockNeteaseMusic_Go is not set
# CONFIG_UnblockNeteaseMusic_NodeJS is not set
EOF
elif [ "$MODEL" = "rpi3" ] || [ "$MODEL" = "rpi4" ];then
cat >> .config <<EOF
# CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-theme-atmaterial=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_nano=y
CONFIG_PACKAGE_wget=y
CONFIG_PACKAGE_luci-app-softethervpn=y
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_PACKAGE_ipv6helper=y
CONFIG_PACKAGE_luci-app-ssr-plus=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Simple_obfs=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_V2ray_plugin=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_V2ray=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Trojan=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Redsocks2=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Kcptun=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_ShadowsocksR_Server=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_DNS2SOCKS=y
CONFIG_PACKAGE_luci-app-smartdns=y
CONFIG_TARGET_IMAGES_GZIP=y
# CONFIG_PACKAGE_luci-app-qbittorrent is not set
# CONFIG_PACKAGE_luci-app-pptp-server is not set
# CONFIG_PACKAGE_luci-app-ipsec-vpnd is not set
EOF
elif [ "$MODEL" = "mir3g" ];then
cat >> .config <<EOF
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_nano=y
CONFIG_PACKAGE_iperf3=y
# CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-theme-netgear=y
#
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_PACKAGE_ipv6helper=y
#
# CONFIG_PACKAGE_natflow-boot is not set
CONFIG_PACKAGE_luci-app-flowoffload=y
#
CONFIG_PACKAGE_luci-app-vlmcsd=y
CONFIG_PACKAGE_luci-app-ssr-plus=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Kcptun=y
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_V2ray is not set
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Xray=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Redsocks2=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_DNS2SOCKS=y
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Trojan is not set
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Trojan-go=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Simple_obfs=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_V2ray_plugin=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_ShadowsocksR_Server=y
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_NaiveProxy is not set
CONFIG_PACKAGE_luci-app-smartdns=y
CONFIG_PACKAGE_luci-app-zerotier=y
# CONFIG_PACKAGE_luci-app-nfs=y
CONFIG_PACKAGE_automount=y
CONFIG_PACKAGE_ddns-scripts_cloudflare.com-v4=y
CONFIG_PACKAGE_luci-app-v2ray-server=y
CONFIG_PACKAGE_luci-app-softethervpn=y
# CONFIG_PACKAGE_luci-app-samba4 is not set
# CONFIG_PACKAGE_luci-app-openvpn-server is not set
# CONFIG_PACKAGE_luci-app-amule is not set
# CONFIG_PACKAGE_luci-app-music-remote-center is not set
# CONFIG_PACKAGE_luci-app-nlbwmon is not set
# CONFIG_PACKAGE_luci-app-adbyby-plus is not set
# CONFIG_PACKAGE_luci-app-xlnetacc is not set
# CONFIG_PACKAGE_luci-app-pptp-server is not set
# CONFIG_PACKAGE_luci-app-ipsec-vpnd is not set
# CONFIG_PACKAGE_luci-app-accesscontrol is not set
# CONFIG_PACKAGE_luci-app-sqm is not set
# CONFIG_PACKAGE_luci-app-qbittorrent is not set
#
# CONFIG_PACKAGE_luci-app-unblockmusic is not set
# CONFIG_UnblockNeteaseMusic_Go is not set
# CONFIG_UnblockNeteaseMusic_NodeJS is not set
EOF
elif [ "$MODEL" = "newifi3" ];then
cat >> .config <<EOF
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_nano=y
CONFIG_PACKAGE_iperf3=y
# CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-theme-netgear=y
#
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_PACKAGE_ipv6helper=y
#
# CONFIG_PACKAGE_natflow-boot is not set
CONFIG_PACKAGE_luci-app-flowoffload=y
#
CONFIG_PACKAGE_luci-app-vlmcsd=y
CONFIG_PACKAGE_luci-app-ssr-plus=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Kcptun=y
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_V2ray is not set
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Xray=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Redsocks2=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_DNS2SOCKS=y
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Trojan is not set
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Trojan-go=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Simple_obfs=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_V2ray_plugin=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_ShadowsocksR_Server=y
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_NaiveProxy is not set
CONFIG_PACKAGE_luci-app-smartdns=y
CONFIG_PACKAGE_luci-app-zerotier=y
CONFIG_PACKAGE_automount=y
CONFIG_PACKAGE_ddns-scripts_cloudflare.com-v4=y
#
# CONFIG_PACKAGE_luci-app-openvpn-server is not set
# CONFIG_PACKAGE_luci-app-amule is not set
# CONFIG_PACKAGE_luci-app-music-remote-center is not set
# CONFIG_PACKAGE_luci-app-nlbwmon is not set
# CONFIG_PACKAGE_luci-app-adbyby-plus is not set
# CONFIG_PACKAGE_luci-app-v2ray-server is not set
# CONFIG_PACKAGE_luci-app-xlnetacc is not set
# CONFIG_PACKAGE_luci-app-qbittorrent is not set
# CONFIG_PACKAGE_luci-app-pptp-server is not set
# CONFIG_PACKAGE_luci-app-ipsec-vpnd is not set
# CONFIG_PACKAGE_luci-app-accesscontrol is not set
# CONFIG_PACKAGE_luci-app-sqm is not set
#
# CONFIG_PACKAGE_luci-app-unblockmusic is not set
# CONFIG_UnblockNeteaseMusic_Go is not set
# CONFIG_UnblockNeteaseMusic_NodeJS is not set
# CONFIG_PACKAGE_luci-app-nfs=y
EOF
elif [ "$MODEL" = "hc5761" ];then
cat >> .config <<EOF
# CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-theme-netgear=y
#
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_PACKAGE_ipv6helper=y
#
CONFIG_PACKAGE_luci-app-vlmcsd=y
CONFIG_PACKAGE_luci-app-ssr-plus=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Kcptun=y
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_V2ray is not set
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Xray=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Redsocks2=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_DNS2SOCKS=y
CONFIG_PACKAGE_luci-app-smartdns=y
CONFIG_PACKAGE_luci-app-zerotier=y
CONFIG_PACKAGE_automount=y
CONFIG_PACKAGE_ddns-scripts_cloudflare.com-v4=y
#
# CONFIG_PACKAGE_luci-app-openvpn-server is not set
# CONFIG_PACKAGE_luci-app-amule is not set
# CONFIG_PACKAGE_luci-app-music-remote-center is not set
# CONFIG_PACKAGE_luci-app-nlbwmon is not set
# CONFIG_PACKAGE_luci-app-adbyby-plus is not set
# CONFIG_PACKAGE_luci-app-v2ray-server is not set
# CONFIG_PACKAGE_luci-app-xlnetacc is not set
# CONFIG_PACKAGE_luci-app-qbittorrent is not set
# CONFIG_PACKAGE_luci-app-pptp-server is not set
# CONFIG_PACKAGE_luci-app-ipsec-vpnd is not set
# CONFIG_PACKAGE_luci-app-accesscontrol is not set
# CONFIG_PACKAGE_luci-app-sqm is not set
#
# CONFIG_PACKAGE_luci-app-unblockmusic is not set
# CONFIG_UnblockNeteaseMusic_Go is not set
# CONFIG_UnblockNeteaseMusic_NodeJS is not set
EOF
fi

# Wireless driver
if [ "$MODEL" = "newifi3" ] || [ "$MODEL" = "mir3g" ];then
if [ $MTK_DRIVER -eq 1 ];then
cat >> .config <<EOF
CONFIG_PACKAGE_kmod-mt7603e=y
CONFIG_PACKAGE_kmod-mt76x2e=y
CONFIG_PACKAGE_luci-app-mtwifi=y
# CONFIG_PACKAGE_kmod-mt7603 is not set
# CONFIG_PACKAGE_kmod-mt76x2 is not set
# CONFIG_PACKAGE_wpad-openssl is not set
EOF
else
cat >> .config <<EOF
# CONFIG_PACKAGE_kmod-mt7603e is not set
# CONFIG_PACKAGE_kmod-mt76x2e is not set
# CONFIG_PACKAGE_luci-app-mtwifi is not set
CONFIG_PACKAGE_kmod-mt7603=y
CONFIG_PACKAGE_kmod-mt76x2=y
CONFIG_PACKAGE_wpad-openssl=y
EOF
fi
fi

if [ $BATMAN -eq 1 ];then
cat >> .config <<EOF
CONFIG_PACKAGE_kmod-batman-adv=y
EOF
fi

if [ $NATFLOW -eq 1 ];then
cat >> .config <<EOF
CONFIG_PACKAGE_natflow-boot=y
# CONFIG_PACKAGE_luci-app-flowoffload is not set
EOF
else
cat >> .config <<EOF
# CONFIG_PACKAGE_natflow-boot is not set
CONFIG_PACKAGE_luci-app-flowoffload=y
EOF
fi

sed -i 's/^[ \t]*//g' ./.config
make defconfig

if [ $ONLY_CONFIG -eq 1 ];then
	exit 0
fi

start_bulid ${THREADS}
