#!/usr/bin/env bash
set -e

# Provided primarily to simplify testing for staging, etc.
RELEASE_URL=${FLUENT_BIT_PACKAGES_URL:-https://packages.fluentbit.io}
RELEASE_KEY=${FLUENT_BIT_PACKAGES_KEY:-$FLUENT_BIT_PACKAGES_URL/fluentbit.key}

echo "================================"
echo " Fluent Bit Installation Script "
echo "================================"
echo "This script requires superuser access to install packages."
echo "You will be prompted for your password by sudo."

# Determine package type to install: https://unix.stackexchange.com/a/6348
# OS used by all - for Debs it must be Ubuntu or Debian
# CODENAME only used for Debs
if [ -f /etc/os-release ]; then
    # Debian uses Dash which does not support source
    # shellcheck source=/dev/null
    . /etc/os-release
    OS=$( echo "${ID}" | tr '[:upper:]' '[:lower:]')
    CODENAME=$( echo "${VERSION_CODENAME}" | tr '[:upper:]' '[:lower:]')
elif lsb_release &>/dev/null; then
    OS=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    CODENAME=$(lsb_release -cs)
else
    OS=$(uname -s)
fi

SUDO=sudo
if [[ $(id -u) -eq 0 ]]; then
    SUDO=''
else
    # Clear any previous sudo permission
    sudo -k
fi

# Now set up repos and install dependent on OS, version, etc.
# Will require sudo
case ${OS} in
    amzn|amazonlinux)
        # We need variable expansion and non-expansion on the URL line to pick up the base URL.
        # Therefore we combine things with sed to handle it.
        $SUDO sh <<SCRIPT
rpm --import $RELEASE_KEY
cat << EOF > /etc/yum.repos.d/fluent-bit.repo
[fluent-bit]
name = Fluent Bit
# Legacy server style
baseurl = $RELEASE_URL/amazonlinux/VERSION_ARCH_SUBSTR
# IaC server style
baseurl = $RELEASE_URL/amazonlinux/VERSION_SUBSTR
gpgcheck=1
repo_gpgcheck=1
gpgkey=$RELEASE_KEY
enabled=1
EOF
sed -i 's|VERSION_ARCH_SUBSTR|\$releasever/\$basearch/|g' /etc/yum.repos.d/fluent-bit.repo
sed -i 's|VERSION_SUBSTR|\$releasever/|g' /etc/yum.repos.d/fluent-bit.repo
cat /etc/yum.repos.d/fluent-bit.repo
yum -y install fluent-bit
SCRIPT
    ;;
    centos|centoslinux|rhel|redhatenterpriselinuxserver|fedora|rocky|almalinux)
        $SUDO sh <<SCRIPT
rpm --import $RELEASE_KEY
cat << EOF > /etc/yum.repos.d/fluent-bit.repo
[fluent-bit]
name = Fluent Bit
# Legacy server style
baseurl = $RELEASE_URL/centos/VERSION_ARCH_SUBSTR
# IaC server style
baseurl = $RELEASE_URL/centos/VERSION_SUBSTR
gpgcheck=1
repo_gpgcheck=1
gpgkey=$RELEASE_KEY
enabled=1
EOF
sed -i 's|VERSION_ARCH_SUBSTR|\$releasever/\$basearch/|g' /etc/yum.repos.d/fluent-bit.repo
sed -i 's|VERSION_SUBSTR|\$releasever/|g' /etc/yum.repos.d/fluent-bit.repo
cat /etc/yum.repos.d/fluent-bit.repo
yum -y install fluent-bit
SCRIPT
    ;;
    ubuntu|debian)
        # Remember apt-key add is deprecated
        # https://wiki.debian.org/DebianRepository/UseThirdParty#OpenPGP_Key_distribution
        $SUDO sh <<SCRIPT
export DEBIAN_FRONTEND=noninteractive
mkdir -p /usr/share/keyrings/
curl $RELEASE_KEY | gpg --dearmor > /usr/share/keyrings/fluentbit-keyring.gpg
cat > /etc/apt/sources.list.d/fluent-bit.list <<EOF
deb [signed-by=/usr/share/keyrings/fluentbit-keyring.gpg] $RELEASE_URL/${OS}/${CODENAME} ${CODENAME} main
EOF
cat /etc/apt/sources.list.d/fluent-bit.list
apt-get -y update
apt-get -y install fluent-bit
SCRIPT
    ;;
    *)
        echo "${OS} not supported."
        exit 1
    ;;
esac

echo ""
echo "Installation completed. Happy Logging!"
echo ""
