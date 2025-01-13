#!/bin/bash

# Update and upgrade system packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install prerequisite packages
echo "Installing prerequisite packages..."
sudo apt install -y git build-essential cmake libusb-1.0-0-dev python3-pip rtl-sdr

# Install RTL-SDR drivers
echo "Cloning and installing RTL-SDR drivers..."
cd ~
git clone https://github.com/osmocom/rtl-sdr.git
cd rtl-sdr
mkdir build
cd build
cmake .. -DINSTALL_UDEV_RULES=ON
make
sudo make install
sudo ldconfig
echo "blacklist dvb_usb_rtl28xxu" | sudo tee -a /etc/modprobe.d/blacklist-rtl.conf
sudo systemctl restart udev

# Test RTL-SDR installation
echo "Testing RTL-SDR installation..."
rtl_test

# Install Dump1090
echo "Installing Dump1090..."
cd ~
git clone https://github.com/antirez/dump1090.git
cd dump1090
make
sudo cp dump1090 /usr/local/bin/

# Install GQRX
echo "Installing GQRX..."
sudo apt install -y gqrx-sdr

# Install SDR++ (SDR Plus+)
echo "Installing SDR++..."
cd ~
wget https://github.com/AlexandreRouma/SDRPlusPlus/releases/download/v1.0.4/sdrpp-1.0.4-linux-x86_64.AppImage
chmod +x sdrpp-1.0.4-linux-x86_64.AppImage
sudo mv sdrpp-1.0.4-linux-x86_64.AppImage /usr/local/bin/sdrpp

# Install Chirp
echo "Installing Chirp..."
sudo apt install -y chirp

# Install Ham Clock
echo "Installing Ham Clock..."
cd ~
wget http://www.clearskyinstitute.com/ham/HamClock-raspberrypi.zip
unzip HamClock-raspberrypi.zip
chmod +x HamClock

# Install FLDIGI and FLRIG
echo "Installing FLDIGI and FLRIG..."
sudo apt install -y fldigi flrig

# Install QSS-TV
echo "Installing QSS-TV..."
sudo apt install -y qsstv

# Install RTL_433
echo "Installing RTL_433..."
cd ~
git clone https://github.com/merbanan/rtl_433.git
cd rtl_433
mkdir build
cd build
cmake ..
make
sudo make install

# Install GPredict
echo "Installing GPredict..."
sudo apt install -y gpredict

# Install XDX
echo "Installing XDX..."
sudo apt install -y xdx

# Cleanup
echo "Cleaning up..."
sudo apt autoremove -y
sudo apt clean

echo "Installation complete! Please reboot your system to finalize the setup."
