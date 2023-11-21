#!/bin/bash
set -e
echo "Running in $(pwd)"
export BOLTDIR=bolts
export CC=${COMPILER:-gcc}
export COMPAT=${COMPAT:-1}
export TEST_CHECK_DBSTMTS=${TEST_CHECK_DBSTMTS:-0}
export DEVELOPER=${DEVELOPER:-1}
export EXPERIMENTAL_FEATURES=${EXPERIMENTAL_FEATURES:-0}
export PATH=$CWD/dependencies/bin:"$HOME"/.local/bin:"$PATH"
export PYTEST_OPTS="--maxfail=5 --suppress-no-test-exit-code ${PYTEST_OPTS}"
export PYTEST_PAR=${PYTEST_PAR:-10}
export PYTEST_SENTRY_ALWAYS_REPORT=1
export SLOW_MACHINE=1
export TEST_CMD=${TEST_CMD:-"make -j $PYTEST_PAR pytest"}
export TEST_DB_PROVIDER=${TEST_DB_PROVIDER:-"sqlite3"}
export TEST_NETWORK=${NETWORK:-"regtest"}
export TIMEOUT=900
export VALGRIND=${VALGRIND:-0}
export FUZZING=${FUZZING:-0}
export LIGHTNINGD_POSTGRES_NO_VACUUM=1

# Fail if any commands fail.
set -e

pip3 install --user pip wheel poetry
poetry export -o /tmp/requirements.txt --without-hashes --with dev
pip install -r /tmp/requirements.txt

git clone https://github.com/lightning/bolts.git ../${BOLTDIR}
git submodule update --init --recursive

./configure CC="$CC"
cat config.vars

cat << EOF > pytest.ini
[pytest]
addopts=-p no:logging --color=yes --timeout=1800 --timeout-method=thread --test-group-random-seed=42
markers =
    slow_test: marks tests as slow (deselect with '-m "not slow_test"')
EOF

if [ "$TARGET_HOST" == "arm-linux-gnueabihf" ] || [ "$TARGET_HOST" == "aarch64-linux-gnu" ] \
   || [ "$TARGET_HOST" == "mips-linux-gnu" ] || [ "$TARGET_HOST" == "mips64-linux-gnuabi64" ] \
   || [ "$TARGET_HOST" == "powerpc-linux-gnu" ] || [ "$TARGET_HOST" == "powerpc64-linux-gnu" ] \
   || [ "$TARGET_HOST" == "s390x-linux-gnu" ] || [ "$TARGET_HOST" == "i686-linux-gnu" ] \
   || [ "$TARGET_HOST" == "riscv64-linux-gnu" ]
then
    export QEMU_LD_PREFIX=/usr/"$TARGET_HOST"/
	export LD_LIBRARY_PATH=/usr/"$TARGET_HOST"/lib 
    export MAKE_HOST="$TARGET_HOST"
    export BUILD=x86_64-pc-linux-gnu
    export AR="$TARGET_HOST"-ar
    export AS="$TARGET_HOST"-as
    export CC="$TARGET_HOST"-gcc
    export CXX="$TARGET_HOST"-g++
    export LD="$TARGET_HOST"-ld
    export STRIP="$TARGET_HOST"-strip
    export CONFIGURATOR_WRAPPER=qemu-"${ARCH}"-static

    wget -q https://zlib.net/fossils/zlib-1.2.13.tar.gz
    tar xf zlib-1.2.13.tar.gz
    cd zlib-1.2.13 || exit 1
    ./configure --prefix="$QEMU_LD_PREFIX"
    make
    sudo make install
    cd .. || exit 1
    rm zlib-1.2.13.tar.gz && rm -rf zlib-1.2.13

    wget -q https://www.sqlite.org/2022/sqlite-src-3400000.zip
    unzip -q sqlite-src-3400000.zip
    cd sqlite-src-3400000 || exit 1
    automake --add-missing --force-missing --copy || true
    ./configure --disable-tcl \
     --enable-static \
     --disable-readline \
     --disable-threadsafe \
     --disable-load-extension \
     --host="$TARGET_HOST" \
     --prefix="$QEMU_LD_PREFIX"
    make
    sudo make install
    cd .. || exit 1
    rm sqlite-src-3400000.zip
    rm -rf sqlite-src-3400000

    ./configure CC="$TARGET_HOST-gcc" --enable-static --disable-rust

    make -s -i -j32 CC="$TARGET_HOST-gcc"
	make -i check VALGRIND=0 PYTEST_PAR=$PYTEST_PAR DEVELOPER=0 TIMEOUT=300
else
    eatmydata make -j32
    # shellcheck disable=SC2086
    eatmydata $TEST_CMD
fi
