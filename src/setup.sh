# 0. Ensure script is run from the correct directory
cd "$(dirname "$0")" || exit 1

# 1. Copy wallpaper
mkdir -p /usr/share/wallpapers/MyWallpaper/contents/images
cp ../resources/unios.jpg /usr/share/wallpapers/MyWallpaper/contents/images/unios.jpg

# 2. Copy unios.png icon
mkdir -p /usr/share/icons/hicolor/256x256/apps
cp ../resources/unios.png /usr/share/icons/hicolor/256x256/apps/unios.png
gtk-update-icon-cache /usr/share/icons/hicolor/ 2>/dev/null

# 3. Set default wallpaper in main.xml
sed -i 's|<default></default>|<default>/usr/share/wallpapers/MyWallpaper/contents/images/unios.jpg</default>|' \
  /usr/share/plasma/wallpapers/org.kde.image/contents/config/main.xml

# 4. Set up skel config directory
mkdir -p /etc/skel/.config/autostart
mkdir -p /etc/skel/.config/default/autostart

# 5. Set Breeze Dark theme
cat > /etc/skel/.config/kdeglobals << 'EOF'
[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop

[General]
ColorScheme=BreezeDark

[Icons]
Theme=breeze-dark

[KDE Action Restrictions]
action/help_about_kde=false
EOF
cp /etc/skel/.config/kdeglobals /etc/skel/.config/default/

# 6. Set Plasma style
cat > /etc/skel/.config/plasmarc << 'EOF'
[Theme]
name=breeze-dark
EOF
cp /etc/skel/.config/plasmarc /etc/skel/.config/default/

# 7. Disable KDE welcome screen
cat > /etc/skel/.config/plasma-welcomerc << 'EOF'
[General]
ShouldShow=false
EOF
cp /etc/skel/.config/plasma-welcomerc /etc/skel/.config/default/

# 8. Disable KDED welcome module
cat > /etc/skel/.config/kded_plasma_welcomerc << 'EOF'
[Module]
autoload=false
EOF
cp /etc/skel/.config/kded_plasma_welcomerc /etc/skel/.config/default/

# 9. Remove plasma-welcome package entirely
apt remove --purge -y plasma-welcome
apt autoremove --purge -y

# 10. Install unidesk
apt install -y ../resources/unidesk_1.0-1_all.deb

# 11. Install unibackpack
apt install -y ../resources/unibackpack_1.0_amd64.deb

# 12. Add unidesk to autostart
cat > /etc/skel/.config/autostart/unidesk.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=UniDesk
Exec=unidesk
Icon=unios
Terminal=false
X-KDE-autostart-condition=false
EOF
cp /etc/skel/.config/autostart/unidesk.desktop /etc/skel/.config/default/autostart/

# 13. Set Kickoff start menu icon
sed -i 's/panel.addWidget("org.kde.plasma.kickoff")/var kickoff = panel.addWidget("org.kde.plasma.kickoff")\nkickoff.currentConfigGroup = ["General"]\nkickoff.writeConfig("icon", "unios")/' \
  /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js

# 14. Remove default desktop shortcuts
rm -f /etc/skel/Desktop/org.kfocus.web.howtos.desktop
rm -f /etc/skel/Desktop/org.kubuntu.web.home.desktop

# 15. Rename Install shortcut to Install UniOS with unios icon
sed -i 's/Name=Install Kubuntu 26.04/Name=Install UniOS/' /usr/share/applications/kubuntu-calamares.desktop
sed -i 's/GenericName=Install Kubuntu/GenericName=Install UniOS/' /usr/share/applications/kubuntu-calamares.desktop
sed -i 's/Icon=system-software-install/Icon=unios/' /usr/share/applications/kubuntu-calamares.desktop
sed -i '/^Name\[/d' /usr/share/applications/kubuntu-calamares.desktop
sed -i '/^GenericName\[/d' /usr/share/applications/kubuntu-calamares.desktop

# 16. Add Install UniOS shortcut to desktop
mkdir -p /etc/skel/Desktop
cp /usr/share/applications/kubuntu-calamares.desktop /etc/skel/Desktop/

# 17. Add UniBackpack shortcut to desktop
cat > /etc/skel/Desktop/unibackpack.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=UniBackpack
Comment=University software installer
Exec=unibackpack
Icon=unibackpack
Terminal=false
Categories=Utility;
EOF
chmod +x /etc/skel/Desktop/unibackpack.desktop

# 18. Add UniOS PPA and install desktop settings
curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x1607DC0CE88E5632F345ECD73946FECCB0BACE79" \
  | gpg --dearmor -o /etc/apt/trusted.gpg.d/unios-ppa.gpg

cat > /etc/apt/sources.list.d/unios.list << 'EOF'
deb https://ppa.launchpadcontent.net/unios-team/ppa/ubuntu noble main
EOF

# Uncomment lines when ready
#apt update
#apt install -y unios-desktop-settings

# 19. Verify everything
echo "=== Wallpaper ===" && ls /usr/share/wallpapers/MyWallpaper/contents/images/
echo "=== Icon ===" && ls /usr/share/icons/hicolor/256x256/apps/unios.png
echo "=== Skel .config ===" && ls /etc/skel/.config/
echo "=== Skel default ===" && ls /etc/skel/.config/default/
echo "=== Autostart ===" && ls /etc/skel/.config/autostart/
echo "=== Desktop ===" && ls /etc/skel/Desktop/
echo "=== Kickoff ===" && grep -n "kickoff" /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js
echo "=== Calamares ===" && grep "Name\|Icon" /usr/share/applications/kubuntu-calamares.desktop
echo "=== UniBackpack ===" && ls /etc/skel/Desktop/unibackpack.desktop
echo "=== PPA ===" && cat /etc/apt/sources.list.d/unios.list