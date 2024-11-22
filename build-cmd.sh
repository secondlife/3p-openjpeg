#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# complain about unset env variables
set -u

OPENJPEG_SOURCE_DIR="openjpeg"

openjpeg="openjp2"
verfile="openjpeg/CMakeLists.txt"
OPENJPEG_VERSION_MAJOR="$(sed -n -E '/^.*OPENJPEG_VERSION_MAJOR ([0-9]+)\)/s//\1/p' "$verfile")"
OPENJPEG_VERSION_MINOR="$(sed -n -E '/^.*OPENJPEG_VERSION_MINOR ([0-9]+)\)/s//\1/p' "$verfile")"
OPENJPEG_VERSION_BUILD="$(sed -n -E '/^.*OPENJPEG_VERSION_BUILD ([0-9]+)\)/s//\1/p' "$verfile")"
OPENJPEG_VERSION="$OPENJPEG_VERSION_MAJOR.$OPENJPEG_VERSION_MINOR.$OPENJPEG_VERSION_BUILD"

if [ -z "$AUTOBUILD" ] ; then
    exit 1
fi

if [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
else
    autobuild="$AUTOBUILD"
fi

stage="$(pwd)/stage"

# load autobuild provided shell functions and variables
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

# remove_cxxstd
source "$(dirname "$AUTOBUILD_VARIABLES_FILE")/functions"

build=${AUTOBUILD_BUILD_ID:=0}
echo "${OPENJPEG_VERSION}.${build}" > "${stage}/VERSION.txt"

pushd "$OPENJPEG_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            load_vsvars

            LL_PLATFORM="-A x64"
            if [ "$AUTOBUILD_WIN_VSPLATFORM" = "Win32" ] ; then
                LL_PLATFORM="-A win32"
            fi

            cmake . -G "$AUTOBUILD_WIN_CMAKE_GEN" $LL_PLATFORM -DCMAKE_INSTALL_PREFIX=$stage \
                    -DCMAKE_C_FLAGS="$LL_BUILD_RELEASE"

            msbuild.exe \
                -t:$openjpeg \
                -p:Configuration=Release \
                -p:Platform=$AUTOBUILD_WIN_VSPLATFORM \
                -p:PlatformToolset=v143 \
                OPENJPEG.sln
            mkdir -p "$stage/lib/release"

            cp bin/Release/$openjpeg{.dll,.lib} "$stage/lib/release"
            mkdir -p "$stage/include/openjpeg"

            if [ "$openjpeg" == "openjpeg" ]
            then # openjpeg 1.x
                 cp libopenjpeg/openjpeg.h "$stage/include/openjpeg/"
            else # openjpeg 2.x
                 cp src/lib/$openjpeg/*.h \
                    "$stage/include/openjpeg/"
            fi
        ;;

        darwin*)
            export MACOSX_DEPLOYMENT_TARGET="$LL_BUILD_DARWIN_DEPLOY_TARGET"

            for arch in x86_64 arm64 ; do
                ARCH_ARGS="-arch $arch"
                opts="${TARGET_OPTS:-$ARCH_ARGS $LL_BUILD_RELEASE}"
                cc_opts="$(remove_cxxstd $opts)"
                cc_opts="$(remove_switch -stdlib=libc++ $cc_opts)"
                ld_opts="$ARCH_ARGS"

                mkdir -p "build_$arch"
                pushd "build_$arch"
                    CFLAGS="$cc_opts" \
                    CXXFLAGS="$opts" \
                    LDFLAGS="$ld_opts" \
                    cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release \
                        -DBUILD_SHARED_LIBS=OFF \
                        -DBUILD_CODEC=OFF \
                        -DCMAKE_C_FLAGS="$cc_opts" \
                        -DCMAKE_CXX_FLAGS="$opts" \
                        -DCMAKE_BUILD_TYPE=Release \
                        -DCMAKE_INSTALL_PREFIX="$stage" \
                        -DCMAKE_INSTALL_LIBDIR="$stage/lib/release/$arch" \
                        -DCMAKE_OSX_ARCHITECTURES:STRING="$arch" \
                        -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET}

                    cmake --build . --config Release
                    cmake --install . --config Release

                    # conditionally run unit tests
                    if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                        ctest -C Release
                    fi
                popd
            done

            # Create universal library
            lipo -create -output "$stage/lib/release/libopenjp2.a" "$stage/lib/release/x86_64/libopenjp2.a" "$stage/lib/release/arm64/libopenjp2.a"

            # Rename to unversioned include dir
            mv "$stage"/include/openjpeg-2.5 "$stage"/include/openjpeg
        ;;

        linux*)
            opts="${TARGET_OPTS:--m$AUTOBUILD_ADDRSIZE $LL_BUILD_RELEASE}"
            plainopts="$(remove_cxxstd $opts)"

            # Handle any deliberate platform targeting
            if [ -z "${TARGET_CPPFLAGS:-}" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            mkdir -p "build"
            pushd "build"
                cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release \
                    -DCMAKE_INSTALL_PREFIX="$stage" \
                    -DCMAKE_INSTALL_LIBDIR="$stage/lib/release" \
                    -DBUILD_SHARED_LIBS=OFF \
                    -DCMAKE_C_FLAGS="$plainopts" \
                    -DCMAKE_CXX_FLAGS="$opts"

                cmake --build . --config Release
                cmake --install . --config Release

                # conditionally run unit tests
                if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                    ctest -C Release
                fi
            popd

            # Rename to unversioned include dir
            mv "$stage"/include/openjpeg-2.5 "$stage"/include/openjpeg
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp LICENSE "$stage/LICENSES/openjpeg.txt"
popd
