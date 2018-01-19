#!/bin/bash -e

install -v -d	${ROOTFS_DIR}/etc/systemd/system/dhcpcd.service.d
install -v -m 644 files/etc/systemd/system/dhcpcd.service.d/wait.conf ${ROOTFS_DIR}/etc/systemd/system/dhcpcd.service.d/

install -v -d ${ROOTFS_DIR}/etc/wpa_supplicant
install -v -m 600 files/etc/wpa_supplicant/wpa_supplicant.conf ${ROOTFS_DIR}/etc/wpa_supplicant/

# setup wifi access point for network config
raspap_user="www-data"
if [ -d ${ROOTFS_DIR}/var/www/html ] ; then rm -rf ${ROOTFS_DIR}/var/www/html; fi;
install -v -d -o ${raspap_user} -g ${raspap_user} ${ROOTFS_DIR}/var/www/html
git clone https://github.com/ctrl-labs/raspap-webgui.git ${ROOTFS_DIR}/var/www/html/
install -v -d ${ROOTFS_DIR}/etc/raspap/hostapd
install -v files/etc/raspap/hostapd/{disablelog.sh,enablelog.sh} ${ROOTFS_DIR}/etc/raspap/hostapd/
install -o ${raspap_user} -g ${raspap_user} files/etc/raspap/raspap.php ${ROOTFS_DIR}/etc/raspap/
install -v -d ${ROOTFS_DIR}/etc/default
install -v files/etc/default/hostapd ${ROOTFS_DIR}/etc/default/
install -v -d ${ROOTFS_DIR}/etc/hostapd
install -v files/etc/hostapd/hostapd.conf ${ROOTFS_DIR}/etc/hostapd/
install -v files/etc/dnsmasq.conf ${ROOTFS_DIR}/etc/
install -v files/etc/dhcpcd.conf ${ROOTFS_DIR}/etc/

# Add a single entry to the sudoers file
function sudo_add() {
  echo "www-data ALL=(ALL) NOPASSWD:$1" >> ${ROOTFS_DIR}/etc/sudoers
}
  # Set commands array
  cmds=(
      '/sbin/ifdown wlan0'
      '/sbin/ifup wlan0'
      '/bin/cat /etc/wpa_supplicant/wpa_supplicant.conf'
      '/bin/cp /tmp/wifidata /etc/wpa_supplicant/wpa_supplicant.conf'
      '/sbin/iwlist wlan0 scan'
      '/sbin/wpa_cli scan_results'
      '/sbin/wpa_cli scan'
      '/sbin/wpa_cli reconfigure'
      '/bin/cp /tmp/hostapddata /etc/hostapd/hostapd.conf'
      '/etc/init.d/hostapd start'
      '/etc/init.d/hostapd stop'
      '/etc/init.d/dnsmasq start'
      '/etc/init.d/dnsmasq stop'
      '/bin/cp /tmp/dhcpddata /etc/dnsmasq.conf'
      '/sbin/shutdown -h now'
      '/sbin/reboot'
      '/sbin/ip link set wlan0 down'
      '/sbin/ip link set wlan0 up'
      '/sbin/ip -s a f label wlan0'
      '/bin/cp /etc/raspap/networking/dhcpcd.conf /etc/dhcpcd.conf'
      '/etc/raspap/hostapd/enablelog.sh'
      '/etc/raspap/hostapd/disablelog.sh'
  )

  # Check if sudoers needs patchin
  if [ $(grep -c www-data ${ROOTFS_DIR}/etc/sudoers) -ne 15 ]; then
      # Sudoers file has incorrect number of commands. Wiping them out.
      echo "Cleaning sudoers file"
      sed -i '/www-data/d' ${ROOTFS_DIR}/etc/sudoers
      echo "Patching system sudoers file"
      # patch /etc/sudoers file
      for cmd in "${cmds[@]}"; do
          sudo_add $cmd
      done
  else
      echo "Sudoers file already patched"
  fi

# enable fastcgi-php for lighttpd
cd ${ROOTFS_DIR}/etc/lighttpd/conf-enabled && \
  ln -s ../conf-available/10-fastcgi.conf 10-fastcgi.conf && \
  ln -s ../conf-available/15-fastcgi-php.conf 15-fastcgi-php.conf
