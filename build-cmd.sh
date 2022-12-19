#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# complain about unset env variables
set -u

OPENJPEG_SOURCE_DIR="openjpeg"

if false
then
    openjpeg="openjpeg"
    verfile="$openjpeg/CMakeLists.txt"
    OPENJPEG_VERSION_MAJOR="$(sed -n -E '/^.*OPENJPEG_VERSION_MAJOR ([0-9]+)\)/s//\1/p' "$verfile")"
    OPENJPEG_VERSION_MINOR="$(sed -n -E '/^.*OPENJPEG_VERSION_MINOR ([0-9]+)\)/s//\1/p' "$verfile")"
    OPENJPEG_VERSION_BUILD="$(sed -n -E '/^.*OPENJPEG_VERSION_BUILD ([0-9]+)\)/s//\1/p' "$verfile")"
    OPENJPEG_VERSION="$OPENJPEG_VERSION_MAJOR.$OPENJPEG_VERSION_MINOR.$OPENJPEG_VERSION_BUILD"
else                            # openjpeg 2.0+
    openjpeg="openjp2"
    verfile="openjpeg/CMakeLists.txt"
    OPENJPEG_VERSION_MAJOR="$(sed -n -E '/^.*OPENJPEG_VERSION_MAJOR ([0-9]+)\)/s//\1/p' "$verfile")"
    OPENJPEG_VERSION_MINOR="$(sed -n -E '/^.*OPENJPEG_VERSION_MINOR ([0-9]+)\)/s//\1/p' "$verfile")"
    OPENJPEG_VERSION_BUILD="$(sed -n -E '/^.*OPENJPEG_VERSION_BUILD ([0-9]+)\)/s//\1/p' "$verfile")"
    OPENJPEG_VERSION="$OPENJPEG_VERSION_MAJOR.$OPENJPEG_VERSION_MINOR.$OPENJPEG_VERSION_BUILD"
fi

if [ -z "$AUTOBUILD" ] ; then 
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
else
    autobuild="$AUTOBUILD"
fi

stage="$(pwd)/stage"

# load autobuild provided shell functions and variables
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

build=${AUTOBUILD_BUILD_ID:=0}
echo "${OPENJPEG_VERSION}.${build}" > "${stage}/VERSION.txt"

pushd "$OPENJPEG_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            load_vsvars

            cmake . -G "$AUTOBUILD_WIN_CMAKE_GEN" -DCMAKE_INSTALL_PREFIX=$stage \
                    -DCMAKE_C_FLAGS="$LL_BUILD_RELEASE"

            build_sln "OPENJPEG.sln" "Release|$AUTOBUILD_WIN_VSPLATFORM" "$openjpeg"
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
            cmake . -GXcode -D'CMAKE_OSX_ARCHITECTURES:STRING=$AUTOBUILD_CONFIGURE_ARCH' \
                    -D'BUILD_SHARED_LIBS:bool=off' -D'BUILD_CODEC:bool=off' \
                    -DCMAKE_INSTALL_PREFIX=$stage -DCMAKE_C_FLAGS="$LL_BUILD_RELEASE"
            xcodebuild -configuration Release -target $openjpeg -project openjpeg.xcodeproj
            xcodebuild -configuration Release -target install -project openjpeg.xcodeproj
            mkdir -p "$stage/lib/release"
            mkdir -p "$stage/include/openjpeg"
            # As of openjpeg 2.0, build products are now installed into
            # directories with version-stamped names. The actual pathname can
            # be found in install_manifest.txt.
            mv -v "$(grep "/libopenjp2.a$" install_manifest.txt)" "$stage/lib/release/libopenjp2.a"

            cp src/lib/$openjpeg/*.h "$stage/include/openjpeg/"
        ;;

        linux*)
            # Force 4.6
            #export CC=gcc-4.6
            #export CXX=g++-4.6

            # Inhibit '--sysroot' nonsense
            export CPPFLAGS=""

            cmake -G"Unix Makefiles" \
                -DCMAKE_INSTALL_PREFIX="$stage" \
                -DBUILD_SHARED_LIBS:bool=off \
                -DCMAKE_INSTALL_DEBUG_LIBRARIES=1 \
                -DCMAKE_C_FLAGS="$LL_BUILD_RELEASE" .
            # From 1.4.0:
            # CFLAGS="-m32" CPPFLAGS="-m32" LDFLAGS="-m32" ./configure --target=i686-linux-gnu --prefix="$stage" --enable-png=no --enable-lcms1=no --enable-lcms2=no --enable-tiff=no
            make
            make install
            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                echo "No unit tests yet"
            fi

            mkdir -p "$stage/lib/release"
            mkdir -p "$stage/include/openjpeg"
            # As of openjpeg 2.0, build products are now installed into
            # directories with version-stamped names. The actual pathname can
            # be found in install_manifest.txt.
            mv -v "$(grep "/libopenjp2.a$" install_manifest.txt)" "$stage/lib/release/libopenjp2.a"

            cp src/lib/$openjpeg/*.h "$stage/include/openjpeg/"
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp LICENSE "$stage/LICENSES/openjpeg.txt"
popd
