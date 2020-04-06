# This is the final logic which controls the build sequence.
# This is very similar to FreeBSD Ports Collection sequence logic.

# The order of _TARGET_STAGES is signficant.
# Consider returning SANITY stage if required

_TARGETS_STAGES=	FETCH EXTRACT PATCH CONFIGURE BUILD STAGE TEST

# --------------------------------------------------------------------------
# --  Sequence definition
# --------------------------------------------------------------------------

# Define the SEQ of actions to take when each target is run, and which targets
# they depend on before executing its SEQ.
#
# The main target has a priority of 500, pre-target priority is 300,
# post-target priority is 700, and target-depends has a priority of 150.
# The remaining targets are slotted according to sequence requirements.

_FETCH_DEP=		# none currently
_FETCH_SEQ=		100:fetch-message \
			300:pre-fetch \
			350:pre-fetch-option \
			400:pre-fetch-opsys \
			450:pre-fetch-script \
			500:do-fetch \
			525:do-fetch-option \
			550:do-fetch-opsys \
			700:post-fetch \
			750:post-fetch-option \
			800:post-fetch-opsys \
			850:post-fetch-script \
			${_USES_fetch}

_EXTRACT_DEP=		fetch
_EXTRACT_SEQ=		100:extract-message \
			150:checksum \
			200:clean-wrkdir \
			250:create-extract-dirs \
			300:pre-extract \
			350:pre-extract-option \
			400:pre-extract-opsys \
			450:pre-extract-script \
			500:do-extract \
			525:do-extract-option \
			550:do-extract-opsys \
			575:shift-wrksrc \
			576:github-relocation \
			577:crate-relocation \
			600:apply-slist \
			625:extract-licenses \
			650:compile-package-desc \
			700:post-extract \
			750:post-extract-option \
			800:post-extract-opsys \
			850:post-extract-script \
			999:extract-fixup-modes \
			${_SITES_extract} \
			${_USES_extract}

_PATCH_DEP=		extract
_PATCH_SEQ=		100:patch-message \
			300:pre-patch \
			350:pre-patch-option \
			400:pre-patch-opsys \
			450:pre-patch-script \
			500:do-patch \
			525:do-patch-option \
			550:do-patch-opsys \
			700:post-patch \
			750:post-patch-option \
			800:post-patch-opsys \
			850:post-patch-script \
			${_USES_patch}

_CONFIGURE_DEP=		patch
_CONFIGURE_SEQ=		200:configure-message \
			300:pre-configure \
			350:pre-configure-option \
			400:pre-configure-opsys \
			450:pre-configure-script \
			500:do-configure \
			525:do-configure-option \
			550:do-configure-opsys \
			700:post-configure \
			750:post-configure-option \
			800:post-configure-opsys \
			850:post-configure-script \
			${_USES_configure}

_BUILD_DEP=		configure
_BUILD_SEQ=		100:build-message \
			300:pre-build \
			350:pre-build-option \
			400:pre-build-opsys \
			450:pre-build-script \
			500:do-build \
			525:do-build-option \
			550:do-build-opsys \
			700:post-build \
			750:post-build-option \
			800:post-build-opsys \
			850:post-build-script \
			${_USES_build}

# STAGE is special in its numbering as it has install and stage,
# so install is the main, and stage goes after.

# Some ports use the compiler and binutils in stage, which means
# they are still building when they should be installing.  To force
# correctness, provide an alternative sequence where pre-install
# and do-install are done during the build stage.

.if defined(INSTALL_REQ_TOOLCHAIN)
_BUILD_SEQ+=		852:stage-dir \
			854:pre-install \
			856:pre-install-option \
			858:pre-install-opsys \
			860:generate-plist \
			862:create-users-groups \
			864:do-install \
			866:do-install-option \
			868:do-install-opsys
.endif

_STAGE_DEP=		build
_STAGE_SEQ=		100:stage-message
.if !defined(INSTALL_REQ_TOOLCHAIN)
_STAGE_SEQ+=		200:stage-dir \
			300:pre-install \
			325:pre-install-option \
			350:pre-install-opsys \
			400:generate-plist \
			450:create-users-groups \
			500:do-install \
			525:do-install-option \
			550:do-install-opsys
.endif
_STAGE_SEQ+=		700:post-install \
			725:post-install-option \
			750:post-install-opsys \
			775:post-install-script \
			800:post-stage \
			820:post-stage-option \
			840:post-stage-opsys \
			850:compress-man \
			860:install-rc-script \
			870:install-smf-manifest \
			880:install-license \
			890:install-desktop-entries \
			900:add-plist-info \
			910:add-plist-docs \
			920:add-plist-examples \
			925:add-plist-nls \
			930:add-plist-licenses \
			940:add-plist-post \
			${POST_PLIST_TARGET:C/^/990:/} \
			995:stage-qa \
			${_USES_install} \
			${_USES_stage}

_TEST_DEP=		stage
_TEST_SEQ=		100:test-message \
			300:pre-test \
			325:pre-test-option \
			350:pre-test-opsys \
			500:do-test \
			525:do-test-option \
			550:do-test-opsys \
			700:post-test \
			750:post-test-option \
			800:post-test-opsys \
			${_USES_test}

# --------------------------------------------------------------------------
# --  Target ordering
# --------------------------------------------------------------------------

# Enforce order for -jN builds
.for _t in ${_TARGETS_STAGES}
.  for s in ${_${_t}_SEQ:O:C/^[0-9]+://}
.    if target(${s})
_PHONY_TARGETS+=	${s}
_${_t}_REAL_SEQ+=	${s}
.    endif
.  endfor
.ORDER: ${_${_t}_DEP} ${_${_t}_REAL_SEQ}
.endfor

# --------------------------------------------------------------------------
# --  pre-* and post-script targets
# --------------------------------------------------------------------------

.for subphase in pre post
.  for name in fetch extract patch configure build install
.    if exists(${SCRIPTDIR}/${subphase}-${name})
.      if !target(${subphase}-${name}-script)
${subphase}-${name}-script:
	@cd ${.CURDIR} && ${SETENV} ${SCRIPTS_ENV} \
		${SH} ${SCRIPTDIR}/${subphase}-${name}
.      endif
.    endif
.  endfor
.endfor

# --------------------------------------------------------------------------
# --  Phase target definition
# --------------------------------------------------------------------------

# Define all of the main targets which depend on a sequence of other targets.
# See above *_SEQ and *_DEP. The _DEP will run before this defined target is
# ran. The _SEQ will run as this target once _DEP is satisfied.

# Names of cookies used to skip already completed stages

EXTRACT_COOKIE=		${WRKDIR}/.done_extract
PATCH_COOKIE=		${WRKDIR}/.done_patch
CONFIGURE_COOKIE=	${WRKDIR}/.done_configure
BUILD_COOKIE=		${WRKDIR}/.done_build
STAGE_COOKIE=		${WRKDIR}/.done_stage

# Disable build
.if defined(NO_BUILD)
build: configure
	@${TOUCH} ${TOUCH_FLAGS} ${BUILD_COOKIE}
.endif

# Disable test
.if defined(NO_TEST)
test: stage
	@${DO_NADA}
.endif

.for target in extract patch configure build stage

.  if !target(${target})
_PHONY_TARGETS+= ${target}
${target}: ${${target:tu}_COOKIE}
.  endif

.  if exists(${${target:tu}_COOKIE})
${${target:tu}_COOKIE}::
	@if [ -e ${.TARGET} ]; then \
		${DO_NADA}; \
	else \
		cd ${.CURDIR} && ${MAKE} ${.TARGET}; \
	fi
.  else
${${target:tu}_COOKIE}: ${_${target:tu}_DEP} ${_${target:tu}_REAL_SEQ}
	@${TOUCH} -f ${.TARGET}
.  endif

.endfor # foreach(targets)

.for target in fetch test
.  if !target(${target})
_PHONY_TARGETS+= ${target}
${target}: ${_${target:tu}_DEP} ${_${target:tu}_REAL_SEQ}
.  endif
.endfor

.PHONY: ${_PHONY_TARGETS}

# --------------------------------------------------------------------------
# --  Special Targets
# --------------------------------------------------------------------------

.if !target(restage)
restage:
	@${RM} -r ${STAGEDIR} ${STAGE_COOKIE} ${INSTALL_COOKIE} ${PACKAGE_COOKIE}
	@cd ${.CURDIR} && ${MAKE} stage
.endif
