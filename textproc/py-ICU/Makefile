# $OpenBSD: Makefile,v 1.25 2021/01/04 14:06:38 sthen Exp $

COMMENT=		Python extension wrapping the ICU C++ API

MODPY_EGG_VERSION=	2.5
DISTNAME=		PyICU-${MODPY_EGG_VERSION}
PKGNAME=		py-ICU-${MODPY_EGG_VERSION}
REVISION=		0

CATEGORIES=		textproc

# MIT
PERMIT_PACKAGE=	Yes

WANTLIB += icudata icui18n icuuc m pthread ${COMPILER_LIBCXX}

MODULES=		lang/python

MODPY_PI=		Yes
MODPY_PYTEST=		Yes
MODPY_SETUPTOOLS=	Yes

### XXX temporaty until next release
GH_ACCOUNT=		ovalhub
GH_PROJECT=		pyicu
GH_TAGNAME=		4051c690e0daa4a2d822fb4f9215a8e808804768
MODPY_PI=		No
### end XXX

FLAVORS=		python3
FLAVOR?=

COMPILER=		base-clang ports-gcc

LIB_DEPENDS=		textproc/icu4c

TEST_DEPENDS=		devel/py-six${MODPY_FLAVOR} \
			devel/py-test${MODPY_FLAVOR}

TESTLIBDIR=	${WRKSRC}/lib.openbsd-${OSREV}-${ARCH}-${MODPY_VERSION}/
TEST_ENV=	PYTHONPATH=${TESTLIBDIR}

.if !${FLAVOR:Mpython3}
WANTLIB +=	${MODPY_WANTLIB}
LIB_DEPENDS +=	${MODPY_LIB_DEPENDS}
.endif

DEBUG_PACKAGES=	${BUILD_PACKAGES}

pre-configure:
	${SUBST_CMD} ${WRKSRC}/setup.py

.include <bsd.port.mk>
