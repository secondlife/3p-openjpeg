#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e
# complain about unset env variables
set -u

OPENJPEG_VERSION="2.0.0"
OPENJPEG_SOURCE_DIR="openjpeg"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
else
    autobuild="$AUTOBUILD"
fi

# load autobuild provided shell functions and variables
set +x
eval "$("$autobuild" source_environment)"
set -x

# set LL_BUILD and friends
set_build_variables convenience Release

stage="$(pwd)/stage"

build=${AUTOBUILD_BUILD_ID:=0}
echo "${OPENJPEG_VERSION}.${build}" > "${stage}/VERSION.txt"

pushd "$OPENJPEG_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            load_vsvars

            cmake . -G "$AUTOBUILD_WIN_CMAKE_GEN" -DCMAKE_INSTALL_PREFIX=$stage \
                    -DCMAKE_C_FLAGS="$LL_BUILD"

            build_sln "OPENJPEG.sln" "Release|$AUTOBUILD_WIN_VSPLATFORM" "openjpeg"
            mkdir -p "$stage/lib/release"
            cp bin/Release/openjp2{.dll,.lib} "$stage/lib/release"
            mkdir -p "$stage/include/openjp2"
            cp libopenjp2/openjpeg.h "$stage/include/openjp2"
        ;;

        darwin*)
            cmake . -GXcode -D'CMAKE_OSX_ARCHITECTURES:STRING=$AUTOBUILD_CONFIGURE_ARCH' \
                    -D'BUILD_SHARED_LIBS:bool=off' -D'BUILD_CODEC:bool=off' \
                    -DCMAKE_INSTALL_PREFIX=$stage -DCMAKE_C_FLAGS="$LL_BUILD"
            xcodebuild -configuration Release -target openjpeg -project openjpeg.xcodeproj
            xcodebuild -configuration Release -target install -project openjpeg.xcodeproj
            mkdir -p "$stage/lib/release"
            cp "$stage/lib/libopenjp2.a" "$stage/lib/release/libopenjp2.a"
            mkdir -p "$stage/include/openjp2"
            cp "$stage/include/openjp2/openjpeg.h" "$stage/include/openjp2"
        ;;

        linux*)
            # Force 4.6
            export CC=gcc-4.6
            export CXX=g++-4.6

            # Inhibit '--sysroot' nonsense
            export CPPFLAGS=""

            cmake -G"Unix Makefiles" \
                -DCMAKE_INSTALL_PREFIX="$stage" \
                -DBUILD_SHARED_LIBS:bool=off \
                -DCMAKE_INSTALL_DEBUG_LIBRARIES=1 \
                -DCMAKE_C_FLAGS="$LL_BUILD" .
            # From 1.4.0:
            # CFLAGS="-m32" CPPFLAGS="-m32" LDFLAGS="-m32" ./configure --target=i686-linux-gnu --prefix="$stage" --enable-png=no --enable-lcms1=no --enable-lcms2=no --enable-tiff=no
            make
            make install
            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                echo "No unit tests yet"
            fi

            mv "$stage/lib" "$stage/release"
            mkdir -p "$stage/lib"
            mv "$stage/release" "$stage/lib"
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp LICENSE "$stage/LICENSES/openjpeg.txt"
popd

pass
