#!/bin/bash -e

install -v -d	${ROOTFS_DIR}/etc/systemd/system/dhcpcd.service.d
install -v -m 644 files/etc/systemd/system/dhcpcd.service.d/wait.conf ${ROOTFS_DIR}/etc/systemd/system/dhcpcd.service.d/

install -v -d ${ROOTFS_DIR}/etc/wpa_supplicant
install -v -m 600 files/etc/wpa_supplicant/wpa_supplicant.conf ${ROOTFS_DIR}/etc/wpa_supplicant/

# setup wifi access point for network config
raspap_user="www-data"
install -v -d -o ${raspap_user} -g ${raspap_user} ${ROOTFS_DIR}/var/www/html
if [ -d ${ROOTFS_DIR}/var/www/html ] ; then rm -rf ${ROOTFS_DIR}/var/www/html; fi;
git clone https://github.com/ctrl-labs/raspap-webgui.git ${ROOTFS_DIR}/var/www/html/
install -v -d ${ROOTFS_DIR}/etc/raspap/hostapd
install -v files/etc/raspap/hostapd/{disablelog.sh,enablelog.sh} ${ROOTFS_DIR}/etc/raspap/hostapd/
install -o ${raspap_user} -g ${raspap_user} files/etc/hostapd/raspap.php ${ROOTFS_DIR}/etc/raspap/
install -v -d ${ROOTFS_DIR}/etc/default
install -v files/etc/default/hostapd ${ROOTFS_DIR}/etc/default/
install -v -d ${ROOTFS_DIR}/etc/hostapd
install -v files/etc/hostapd/hostapd.conf ${ROOTFS_DIR}/etc/hostapd/
install -v files/etc/dnsmasq.conf ${ROOTFS_DIR}/etc/
install -v files/etc/dhcpcd.conf ${ROOTFS_DIR}/etc/
# Generate required lines for Rasp AP to place into rc.local file.
# #RASPAP is for removal script
lines=(
'echo 1 > /proc/sys/net/ipv4/ip_forward #RASPAP'
'iptables -t nat -A POSTROUTING -j MASQUERADE #RASPAP'
)

for line in "${lines[@]}"; do
    if grep "$line" /etc/rc.local > /dev/null; then
        echo "$line: Line already added"
    else
        sed -i "s/exit 0/$line\nexit0/" /etc/rc.local
        echo "Adding line $line"
    fi
done

# Add a single entry to the sudoers file
function sudo_add() {
    bash -c "echo \"www-data ALL=(ALL) NOPASSWD:$1\" | (EDITOR=\"tee -a\" visudo)" \
        || install_error "Unable to patch /etc/sudoers"
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
  if [ $(grep -c www-data /etc/sudoers) -ne 15 ]; then
      # Sudoers file has incorrect number of commands. Wiping them out.
      install_log "Cleaning sudoers file"
      sed -i '/www-data/d' /etc/sudoers
      install_log "Patching system sudoers file"
      # patch /etc/sudoers file
      for cmd in "${cmds[@]}"; do
          sudo_add $cmd
      done
  else
      install_log "Sudoers file already patched"
  fi

# FIXME: enable lighttpd module
# enable fastcgi-php for lighttpd
#cd /etc/lighttpd/conf-enabled && \
#  ln -s ../conf-available/10-fastcgi.cong 10-fastcgi.conf && \
#  ln -s ../conf-available/15-fastcgi-php.conf 15-fastcgi-php.conf
