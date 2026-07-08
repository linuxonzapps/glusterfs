#!/bin/bash
set -e -o pipefail
read -ra arr <<< "$@"
version=${arr[1]}
trap 0 1 2 ERR
# Extract DISTRO details for tagging
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="$ID-$VERSION_ID"
    if [ "$VERSION_CODENAME" != "" ]; then
        DISTRO="$ID-$VERSION_CODENAME"
    fi
fi
current_dir="$PWD"
echo $DISTRO > .distro_zab.txt
apt update; apt install sudo git rpm -y
# Clone linux-on-ibm-z to keep it current
git clone https://github.com/linux-on-ibm-z/scripts.git /tmp/linux-on-ibm-z
# Build Debian and RPM packages
bash /tmp/linux-on-ibm-z-scripts/GlusterFS/${version}/build_glusterfs.sh -y
# Build Debian package - based on https://github.com/gluster/Gluster-Builds/blob/main/build.sh
apt-get update && apt-get install -y git make automake autoconf libtool flex bison pkg-config sed libssl-dev libxml2-dev python2-dev python3-dev libaio-dev libibverbs-dev libreadline-dev libglib2.0-dev liburcu-dev librdmacm-dev libacl1-dev devscripts build-essential lintian libsqlite3-dev liburing-dev libdb-dev libtirpc-dev attr firewalld dh-python debhelper autotools-dev wget libfuse3-dev libgoogle-perftools-dev
cd ${current_dir}/glusterfs && make dist
cp glusterfs-${version}.tar.gz ../../
tar -xzvf glusterfs-${version}.tar.gz
ln -s glusterfs-${version}.tar.gz glusterfs_${version}.orig.tar.gz
git clone http://github.com/gluster/glusterfs-debian.git
cd glusterfs-debian/ && git checkout -b $VERSION_CODENAME-11-local origin/$VERSION_CODENAME-glusterfs-11
sed -i "1i glusterfs (${version}-ubuntu1~$VERSION_CODENAME1) $VERSION_CODENAME; urgency=medium\n\n  * GlusterFS ${version} GA\n\n -- GlusterFS GlusterFS deb packages <deb.packages@gluster.org>  `date +"%a, %d %b %Y %T %z"`\n" debian/changelog
cp -a debian ../glusterfs-${version}/
cd ../glusterfs-${version}
debuild -us -uc
cd ../ && mkdir tmp && cd tmp && cp ../*.*deb . && tar cvfz glusterfs-${version}-linux-s390x.tar.gz *
# Copy generated Debian and RPM packages
mv glusterfs-${version}-linux-s390x.tar.gz ${current_dir}
exit 0
