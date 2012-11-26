# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-fs/udev/udev-9999.ebuild,v 1.118 2012/11/01 20:40:19 williamh Exp $

EAPI=4

KV_min=2.6.39

inherit autotools eutils linux-info

if [[ ${PV} = 9999* ]]
then
	EGIT_REPO_URI="git://github.com/gentoo/eudev.git"
	inherit git-2
else
	patchset=
	SRC_URI="http://www.freedesktop.org/software/systemd/systemd-${PV}.tar.xz"
	if [[ -n "${patchset}" ]]
		then
				SRC_URI="${SRC_URI}
					http://dev.gentoo.org/~williamh/dist/${P}-patches-${patchset}.tar.bz2"
			fi
	KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~m68k ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86"
fi

DESCRIPTION="Linux dynamic and persistent device naming support (aka userspace devfs)"
HOMEPAGE="https://github.com/gentoo/udev-ng"

LICENSE="LGPL-2.1 MIT GPL-2"
SLOT="0"
IUSE="acl doc gudev hwdb kmod introspection keymap +modules +openrc selinux static-libs"

RESTRICT="test"

COMMON_DEPEND="acl? ( sys-apps/acl )
	gudev? ( dev-libs/glib:2 )
	introspection? ( >=dev-libs/gobject-introspection-1.31.1 )
	selinux? ( sys-libs/libselinux )
	>=sys-apps/util-linux-2.20
	!<sys-libs/glibc-2.11"

DEPEND="${COMMON_DEPEND}
	dev-util/gperf
	>=dev-util/intltool-0.40.0
	virtual/pkgconfig
	virtual/os-headers
	!<sys-kernel/linux-headers-${KV_min}
	doc? ( dev-util/gtk-doc )"

if [[ ${PV} = 9999* ]]
then
	DEPEND="${DEPEND}
		app-text/docbook-xsl-stylesheets
		dev-libs/libxslt"
fi

RDEPEND="${COMMON_DEPEND}
	hwdb? ( sys-apps/hwids )
	openrc? ( >=sys-fs/udev-init-scripts-16
		!<sys-apps/openrc-0.9.9 )
	!sys-apps/coldplug
	!sys-apps/systemd
	!<sys-fs/lvm2-2.02.45
	!sys-fs/device-mapper
	!<sys-fs/udev-init-scripts-16
	!<sys-kernel/dracut-017-r1
	!<sys-kernel/genkernel-3.4.25"

S="${WORKDIR}/udev-${PV}"

udev_check_KV()
{
	if kernel_is lt ${KV_min//./ }
	then
		return 1
	fi
	return 0
}

pkg_setup()
{
	# required kernel options
	CONFIG_CHECK="~DEVTMPFS"
	ERROR_DEVTMPFS="DEVTMPFS is not set in this kernel. Udev will not run."

	linux-info_pkg_setup

	if ! udev_check_KV
	then
		eerror "Your kernel version (${KV_FULL}) is too old to run ${P}"
		eerror "It must be at least ${KV_min}!"
	fi

	KV_FULL_SRC=${KV_FULL}
	get_running_version
	if ! udev_check_KV
	then
		eerror
		eerror "Your running kernel version (${KV_FULL}) is too old"
		eerror "for this version of udev."
		eerror "You must upgrade your kernel or downgrade udev."
	fi
}

src_prepare()
{
	# backport some patches
	if [[ -n "${patchset}" ]]
	then
		EPATCH_SUFFIX=patch EPATCH_FORCE=yes epatch
	fi

	# change rules back to group uucp instead of dialout for now
	sed -e 's/GROUP="dialout"/GROUP="uucp"/' \
		-i rules/*.rules \
	|| die "failed to change group dialout to uucp"

	if [[ ! -e configure ]]
	then
		if use doc
		then
			gtkdocize --docdir docs || die "gtkdocize failed"
		else
			echo 'EXTRA_DIST =' > docs/gtk-doc.make
		fi
		eautoreconf
	else
		elibtoolize
	fi
}

src_configure()
{
	local econf_args

	econf_args=(
		ac_cv_search_cap_init=
		ac_cv_header_sys_capability_h=yes
		DBUS_CFLAGS=' '
		DBUS_LIBS=' '
		--prefix=/
		--with-rootprefix=/
		--docdir=/usr/share/doc/${PF}
		--libdir=/$(get_libdir)
		--with-firmware-path=/usr/lib/firmware/updates:/usr/lib/firmware:/lib/firmware/updates:/lib/firmware
		--with-html-dir=/usr/share/doc/${PF}/html
		--with-rootlibdir=/$(get_libdir)
		--enable-split-usr
		$(use_enable acl)
		$(use_enable doc gtk-doc)
		$(use_enable gudev)
		$(use_enable introspection)
		$(use_enable keymap)
		$(use_enable kmod libkmod)
		$(use_enable modules)
		$(use_enable selinux)
		$(use_enable static-libs static)
	)
	econf "${econf_args[@]}"
}

src_install()
{
	local lib_LTLIBRARIES=libudev.la \
		pkgconfiglib_DATA=src/libudev/libudev.pc

	if use gudev
	then
		lib_LTLIBRARIES+=" libgudev-1.0.la"
		pkgconfiglib_DATA+=" src/gudev/gudev-1.0.pc"
	fi

	emake DESTDIR="${D}" install
#	if use doc
#	then
#		emake -C docs/libudev DESTDIR="${D}" install
#		use gudev && emake -C docs/gudev DESTDIR="${D}" install
#	fi
#	dodoc TODO
#
	prune_libtool_files --all
#	rm -rf "${D}"/usr/share/doc/${PF}/LICENSE.*
#
#	# install gentoo-specific rules
#	insinto /usr/lib/udev/rules.d
#	doins "${FILESDIR}"/40-gentoo.rules
#
#	# install udevadm symlink
#	dosym ../usr/bin/udevadm /sbin/udevadm
}

pkg_preinst()
{
	local htmldir
	for htmldir in gudev libudev; do
		if [[ -d ${ROOT}usr/share/gtk-doc/html/${htmldir} ]]
		then
			rm -rf "${ROOT}"usr/share/gtk-doc/html/${htmldir}
		fi
		if [[ -d ${D}/usr/share/doc/${PF}/html/${htmldir} ]]
		then
			dosym ../../doc/${PF}/html/${htmldir} \
				/usr/share/gtk-doc/html/${htmldir}
		fi
	done
	preserve_old_lib /$(get_libdir)/libudev.so.0
}

pkg_postinst()
{
	mkdir -p "${ROOT}"/run

	# "losetup -f" is confused if there is an empty /dev/loop/, Bug #338766
	# So try to remove it here (will only work if empty).
	rmdir "${ROOT}"/dev/loop 2>/dev/null
	if [[ -d ${ROOT}/dev/loop ]]
	then
		ewarn "Please make sure your remove /dev/loop,"
		ewarn "else losetup may be confused when looking for unused devices."
	fi

	# people want reminders, I'll give them reminders.  Odds are they will
	# just ignore them anyway...

	# 64-device-mapper.rules now gets installed by sys-fs/device-mapper
	# remove it if user don't has sys-fs/device-mapper installed, 27 Jun 2007
	if [[ -f ${ROOT}/etc/udev/rules.d/64-device-mapper.rules ]] &&
		! has_version sys-fs/device-mapper
	then
			rm -f "${ROOT}"/etc/udev/rules.d/64-device-mapper.rules
			einfo "Removed unneeded file 64-device-mapper.rules"
	fi

	# http://bugs.gentoo.org/440462
	if [[ ${REPLACING_VERSIONS} ]] && [[ ${REPLACING_VERSIONS} < 141 ]]; then
		ewarn
		ewarn "If you build an initramfs including udev, please make sure the"
		ewarn "/usr/bin/udevadm binary gets included, Also, change your scripts to"
		ewarn "use it, as it replaces the old udevinfo and udevtrigger helpers."

		ewarn
		ewarn "mount options for /dev are no longer set in /etc/udev/udev.conf."
		ewarn "Instead, /etc/fstab should be used. This matches other mount points."
	fi

	if [[ ${REPLACING_VERSIONS} ]] && [[ ${REPLACING_VERSIONS} < 151 ]]; then
		ewarn
		ewarn "Rules for /dev/hd* devices have been removed."
		ewarn "Please migrate to libata."
	fi

	if [[ ${REPLACING_VERSIONS} ]] && [[ ${REPLACING_VERSIONS} < 189 ]]; then
		ewarn
		ewarn "action_modeswitch has been removed by upstream."
		ewarn "Please use sys-apps/usb_modeswitch."

		if use acl; then
			ewarn
			ewarn "The udev-acl functionality has been moved."
			ewarn "If you are not using systemd, this is handled by ConsoleKit."
			ewarn "Otherwise, you need to make sure that systemd is emerged with"
			ewarn "the acl use flag active."
		fi

		ewarn
		ewarn "Upstream has removed the persistent-net and persistent-cd rules"
		ewarn "generator. If you need persistent names for these devices,"
		ewarn "place udev rules for them in ${ROOT}etc/udev/rules.d."
		ewarn "Be aware that you cannot directly swap device names, so persistent"
		ewarn "rules for network devices should be like the ones at the following"
		ewarn "URL:"
		ewarn "http://bugs.gentoo.org/show_bug.cgi?id=433746#c1"
	fi

	ewarn
	ewarn "You need to restart udev as soon as possible to make the upgrade go"
	ewarn "into effect."
	ewarn "The method you use to do this depends on your init system."

	preserve_old_lib_notify /$(get_libdir)/libudev.so.0

	elog
	elog "For more information on udev on Gentoo, writing udev rules, and"
	elog "         fixing known issues visit:"
	elog "         http://www.gentoo.org/doc/en/udev-guide.xml"
}
