#!/usr/bin/env bash

# automate the installation of a specific version of Chrome and Chromedriver for the capybara suite

# version testées sans succès :
# 124.0.6367.60
# 123.0.6312.122
# 122.0.6261.128
# 120.0.6099.2
# 117.0.5938.149
# 113.0.5672.126

# https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json
version_chromedriver=123.0.6312.122

# https://www.ubuntuupdates.org/package/google_chrome/stable/main/base/google-chrome-stable?id=202706&page=3
version_browser=123.0.6312.122

wget --no-verbose -O /tmp/chrome.deb "https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${version_browser}-1_amd64.deb"
curl -fsSL https://storage.googleapis.com/chrome-for-testing-public/${version_chromedriver}/linux64/chromedriver-linux64.zip -o chromedriver.zip

apt remove -y google-chrome-stable
apt install -y /tmp/chrome.deb
rm /tmp/chrome.deb
unzip chromedriver.zip
mv chromedriver-linux64/chromedriver /usr/bin/chromedriver
rm chromedriver.zip
rm -fr chromedriver-linux64
chmod +x /usr/bin/chromedriver

chromedriver -v
google-chrome --version
