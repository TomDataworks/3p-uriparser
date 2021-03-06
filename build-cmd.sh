#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

URIPARSER_VERSION="0.8.4"
URIPARSER_SOURCE_DIR="uriparser"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autobuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

top="$(pwd)"
stage="$top"/stage

pushd "$URIPARSER_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        "windows")
            load_vsvars

            build_sln "win32/Visual_Studio_2015/uriparser.sln" "Debug" "Win32" "uriparser"
            build_sln "win32/Visual_Studio_2015/uriparser.sln" "Release" "Win32" "uriparser"

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp -a "win32/Visual_Studio_2015/Win32/Debug/uriparser.lib" \
                "$stage/lib/debug/uriparserd.lib"
            cp -a "win32/Visual_Studio_2015/Win32/Release/uriparser.lib" \
                "$stage/lib/release/uriparser.lib"
            mkdir -p "$stage/include/uriparser"
            cp -a include/uriparser/*.h "$stage/include/uriparser"
        ;;
		
        "windows64")
            load_vsvars

            build_sln "win32/Visual_Studio_2015/uriparser.sln" "Debug" "x64" "uriparser"
            build_sln "win32/Visual_Studio_2015/uriparser.sln" "Release" "x64" "uriparser"

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp -a "win32/Visual_Studio_2015/x64/Debug/uriparser.lib" \
                "$stage/lib/debug/uriparserd.lib"
            cp -a "win32/Visual_Studio_2015/x64/Release/uriparser.lib" \
                "$stage/lib/release/uriparser.lib"
            mkdir -p "$stage/include/uriparser"
            cp -a include/uriparser/*.h "$stage/include/uriparser"
        ;;

        "darwin")
            # Select SDK with full path.  This shouldn't have much effect on this
            # build but adding to establish a consistent pattern.
            #
            # sdk=/Developer/SDKs/MacOSX10.6.sdk/
            # sdk=/Developer/SDKs/MacOSX10.7.sdk/
            # sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.6.sdk/
            sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk/


            # Keep min version back at 10.5 if you are using the
            # old llqtwebkit repo which builds on 10.5 systems.
            # At 10.6, zlib will start using __bzero() which doesn't
            # exist there.
            opts="${TARGET_OPTS:--arch i386 -arch x86_64 -iwithsysroot $sdk -mmacosx-version-min=10.8}"

            # Debug first
            CFLAGS="$opts -O0 -gdwarf-2 -fPIC -DPIC" \
                LDFLAGS="-Wl,-install_name,\"${install_name}\" -Wl,-headerpad_max_install_names" \
                ./configure --prefix="$stage" --includedir="$stage/include" --libdir="$stage/lib/debug" --disable-test --disable-doc --enable-shared=no
            make
            make install
            make distclean

            # Now release
            CFLAGS="$opts -O3 -gdwarf-2 -fPIC -DPIC" \
                LDFLAGS="-Wl,-install_name,\"${install_name}\" -Wl,-headerpad_max_install_names" \
                ./configure --prefix="$stage" --includedir="$stage/include" --libdir="$stage/lib/release" --disable-test --disable-doc --enable-shared=no
            make
            make install
            make distclean
        ;;

        "linux")
            # Linux build environment at Linden comes pre-polluted with stuff that can
            # seriously damage 3rd-party builds.  Environmental garbage you can expect
            # includes:
            #
            #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
            #    DISTCC_LOCATION            top            branch      CC
            #    DISTCC_HOSTS               build_name     suffix      CXX
            #    LSDISTCC_ARGS              repo           prefix      CFLAGS
            #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
            #
            # So, clear out bits that shouldn't affect our configure-directed build
            # but which do nonetheless.
            #
            # unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS

            # Prefer gcc-4.8 if available.
            if [[ -x /usr/bin/gcc-4.8 && -x /usr/bin/g++-4.8 ]]; then
                export CC=/usr/bin/gcc-4.8
                export CXX=/usr/bin/g++-4.8
            fi

            # Default target to 32-bit
            opts="${TARGET_OPTS:--m32}"

            HARDENED="-fstack-protector -D_FORTIFY_SOURCE=2"

            # Handle any deliberate platform targeting
            if [ -z "$TARGET_CPPFLAGS" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            # Debug first
            CFLAGS="$opts -Og -g -fPIC -DPIC" CXXFLAGS="$opts -O0 -g -fPIC -DPIC -std=c++11" \
                ./configure --prefix="$stage" --includedir="$stage/include" --libdir="$stage/lib/debug" --disable-test --with-pic
            make
            make install

            # clean the build artifacts
            make distclean

            # Release last
            CFLAGS="$opts -O3 $HARDENED -fPIC -DPIC" CXXFLAGS="$opts -O3 $HARDENED -fPIC -DPIC -std=c++11" \
                ./configure --prefix="$stage" --includedir="$stage/include" --libdir="$stage/lib/release" --disable-test --with-pic
            make
            make install

            # clean the build artifacts
            make distclean
        ;;


        "linux64")
            # Linux build environment at Linden comes pre-polluted with stuff that can
            # seriously damage 3rd-party builds.  Environmental garbage you can expect
            # includes:
            #
            #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
            #    DISTCC_LOCATION            top            branch      CC
            #    DISTCC_HOSTS               build_name     suffix      CXX
            #    LSDISTCC_ARGS              repo           prefix      CFLAGS
            #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
            #
            # So, clear out bits that shouldn't affect our configure-directed build
            # but which do nonetheless.
            #
            # unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS

            # Prefer gcc-4.8 if available.
            if [[ -x /usr/bin/gcc-4.8 && -x /usr/bin/g++-4.8 ]]; then
                export CC=/usr/bin/gcc-4.8
                export CXX=/usr/bin/g++-4.8
            fi

            # Default target to 64-bit
            opts="${TARGET_OPTS:--m64}"

            HARDENED="-fstack-protector -D_FORTIFY_SOURCE=2"

            # Handle any deliberate platform targeting
            if [ -z "$TARGET_CPPFLAGS" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            # Debug first
            CFLAGS="$opts -Og -g -fPIC -DPIC" CXXFLAGS="$opts -Og -g -fPIC -DPIC -std=c++11" \
                ./configure --prefix="$stage" --includedir="$stage/include" --libdir="$stage/lib/debug" --disable-test --with-pic
            make
            make install

            # clean the build artifacts
            make distclean

            # Release last
            CFLAGS="$opts -O3 $HARDENED -fPIC -DPIC" CXXFLAGS="$opts -O3 $HARDENED -fPIC -DPIC -std=c++11" \
                ./configure --prefix="$stage" --includedir="$stage/include" --libdir="$stage/lib/release" --disable-test --with-pic
            make
            make install

            # clean the build artifacts
            make distclean
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    pwd
    echo "${URIPARSER_VERSION}" > "${stage}/VERSION.txt"
    cp -a COPYING "$stage/LICENSES/uriparser.txt"
popd

pass











