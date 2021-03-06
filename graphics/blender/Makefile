# $OpenBSD: Makefile,v 1.100 2021/01/01 22:57:46 sthen Exp $

ONLY_FOR_ARCHS = amd64

COMMENT =	3D creation software

DISTNAME =	blender-2.91.0
REVISION =	0

CATEGORIES =	graphics

HOMEPAGE =	https://www.blender.org/

MAINTAINER =	Dimitri Karamazov <deserter666@danwin1210.me>

# GPLv2+
PERMIT_PACKAGE =	Yes

WANTLIB += ${MODPY_WANTLIB}
WANTLIB += ${COMPILER_LIBCXX} GL GLEW Half-2_5 Iex-2_5 IlmImf-2_5
WANTLIB += IlmThread-2_5 Imath-2_5 OpenColorIO OpenImageIO SDL2
WANTLIB += X11 Xfixes Xi Xrender Xxf86vm avcodec avdevice avformat
WANTLIB += avutil boost_atomic-mt boost_chrono-mt boost_date_time-mt
WANTLIB += boost_filesystem-mt boost_regex-mt boost_system-mt
WANTLIB += boost_thread-mt c fftw3 freetype gmp gmpxx jpeg m openal
WANTLIB += openjp2 png potrace sndfile swscale tbb tiff tinyxml
WANTLIB += util yaml-cpp z

MASTER_SITES =	https://download.blender.org/source/ \
		http://mirror.cs.umn.edu/blender.org/source/

EXTRACT_SUFX = .tar.xz

MODULES =	devel/cmake \
		lang/python

COMPILER =	base-clang ports-gcc

MODPY_VERSION =	${MODPY_DEFAULT_VERSION_3}

CONFIGURE_ARGS =	-DPYTHON_INCLUDE_DIR="${MODPY_INCDIR}" \
			-DPYTHON_VERSION=${MODPY_VERSION} \
			-DWITH_INTERNATIONAL=OFF \
			-DWITH_OPENMP=OFF \
			-DWITH_SYSTEM_GLEW=ON \
			-DWITH_CYCLES_EMBREE=OFF \
			-DWITH_JACK=OFF

BUILD_DEPENDS = math/py-numpy${MODPY_FLAVOR}
LIB_DEPENDS =	audio/libsndfile \
		audio/openal \
		devel/boost \
		devel/gmp,-cxx \
		devel/sdl2 \
		devel/tbb \
		graphics/ffmpeg \
		graphics/glew \
		graphics/jpeg \
		graphics/opencolorio \
		graphics/openexr \
		graphics/openimageio \
		graphics/openjp2 \
		graphics/png \
		graphics/potrace \
		graphics/tiff \
		math/fftw3 \
		${MODPY_LIB_DEPENDS}
RUN_DEPENDS =	devel/desktop-file-utils \
		math/py-numpy${MODPY_FLAVOR} \
		x11/gnome/librsvg

NO_TEST =	Yes

CXXFLAGS +=	-I${LOCALBASE}/include -I${X11BASE}/include
CFLAGS +=	-I${LOCALBASE}/include

MODPY_ADJ_FILES =	release/bin/blender-thumbnailer.py \
			release/scripts/modules/bl_i18n_utils/merge_po.py \
			release/scripts/modules/bl_i18n_utils/utils_rtl.py \
			release/scripts/modules/blend_render_info.py \
			release/scripts/addons/io_curve_svg/svg_util_test.py \
			release/scripts/addons/io_scene_fbx/fbx2json.py \
			release/scripts/addons/io_scene_fbx/json2fbx.py \
			release/scripts/addons/sun_position/geo.py \
			release/datafiles/alert_icons_update.py \
			release/datafiles/blender_icons_geom_update.py \
			release/datafiles/blender_icons_update.py \
			release/datafiles/ctodata.py \
			release/datafiles/prvicons_update.py

post-build:
	${MODPY_BIN} ${MODPY_LIBDIR}/compileall.py \
		${WRKSRC}/release/scripts \
		${WRKSRC}/release/datafiles \
		${WRKSRC}/intern/cycles/blender/addon

do-install:
	${INSTALL_SCRIPT} ${FILESDIR}/blender ${PREFIX}/bin
	${SUBST_CMD} ${PREFIX}/bin/blender
	${INSTALL_PROGRAM} ${WRKBUILD}/bin/blender ${PREFIX}/bin/blender-bin
	${INSTALL_SCRIPT} ${WRKSRC}/release/bin/blender-thumbnailer.py \
		${PREFIX}/bin/blender-thumbnailer
	${INSTALL_DATA_DIR} ${PREFIX}/share/blender/scripts
	${INSTALL_DATA_DIR} ${PREFIX}/share/blender/datafiles
	cd ${WRKSRC}/release/scripts && pax -rw . \
		${PREFIX}/share/blender/scripts
	${INSTALL_DATA_DIR} ${PREFIX}/share/blender/scripts/addons/cycles
	cd ${WRKSRC}/intern/cycles/blender/addon && pax -rw . \
		${PREFIX}/share/blender/scripts/addons/cycles
	cd ${WRKSRC}/release/datafiles && pax -rw . \
		${PREFIX}/share/blender/datafiles
	${INSTALL_DATA_DIR} ${PREFIX}/share/doc/blender
	${INSTALL_DATA} ${WRKSRC}/release/license/* \
		${PREFIX}/share/doc/blender
	${INSTALL_DATA} ${WRKSRC}/release/text/copy* \
		${PREFIX}/share/doc/blender
	${INSTALL_DATA_DIR} ${PREFIX}/share/applications
	${INSTALL_DATA} ${WRKSRC}/release/freedesktop/blender.desktop \
		${PREFIX}/share/applications
	${INSTALL_DATA_DIR} ${PREFIX}/share/pixmaps
	${INSTALL_DATA} \
		${WRKSRC}/release/freedesktop/icons/scalable/apps/blender.svg \
		${PREFIX}/share/pixmaps
	${MODPY_BIN} ${WRKSRC}/doc/manpage/blender.1.py \
		${WRKBUILD}/bin/blender ${PREFIX}/man/man1/blender.1

.include <bsd.port.mk>
