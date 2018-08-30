import os
import sys
import urllib.request
import re
import shutil

LATEST_URL = 'https://bitcoin.jonasschnelli.ch/build/nightly/latest'
BUILD_URL = 'https://bitcointools.jonasschnelli.ch/data/builds/{}/{}'
ARCHIVE_RE = 'bitcoin-0\.[0-9]+\.99-x86_64-linux-gnu(-debug)?\.tar\.gz'
ARCHIVE_EXT = 'tar.gz'


def get_lines(url):
    return urllib.request.urlopen(url).read().decode('utf-8').splitlines()


def main():
    root_folder = os.path.abspath(os.path.dirname(__file__))
    src_dir = os.path.join(root_folder, 'bitcoin', '')
    assert os.path.isdir(src_dir)  # Make sure to git clone bitcoin
    import zmq #noqa

    for line in get_lines(LATEST_URL):
        if 'embed-responsive-item' in line:
            build_id = int(
                re.sub('^.*builds/([0-9]+)/.*$', '\g<1>', line.strip()))
            break
    print('build id: {}'.format(build_id))

    for line in get_lines(BUILD_URL.format(build_id, '')):
        if '-x86_64-linux-gnu.tar.gz' in line:
            archive_gitian_name = re.sub('^.*({}).*$'.format(ARCHIVE_RE),
                                         '\g<1>', line.strip())
        if '-x86_64-linux-gnu-debug.tar.gz' in line:
            archive_gitian_name_dbg = re.sub('^.*({}).*$'.format(ARCHIVE_RE),
                                         '\g<1>', line.strip())
    print('filename: {}'.format(archive_gitian_name))
    print('filename: {}'.format(archive_gitian_name_dbg))
    version = int(
        re.sub('bitcoin-0.(\d+).99-.*', '\g<1>', archive_gitian_name))
    print('version: {}'.format(version))

    archive_name = 'bitcoin-core-nightly.{}'.format(ARCHIVE_EXT)
    archive_name_dbg = 'bitcoin-core-nightly-dbg.{}'.format(ARCHIVE_EXT)
    with open(archive_name, 'wb') as archive:
        archive.write(
            urllib.request.urlopen(
                BUILD_URL.format(build_id, archive_gitian_name)).read())
    with open(archive_name_dbg, 'wb') as archive:
        archive.write(
            urllib.request.urlopen(
                BUILD_URL.format(build_id, archive_gitian_name_dbg)).read())

    build_dir = os.path.join(root_folder, 'build_dir')
    shutil.unpack_archive(archive_name, build_dir)
    shutil.unpack_archive(archive_name_dbg, build_dir)
    build_dir = os.path.join(build_dir, 'bitcoin-0.{}.99'.format(version), '')

    build_dir_src = os.path.join(build_dir, 'src')
    shutil.rmtree(build_dir_src, ignore_errors=True)
    os.rename(src=os.path.join(build_dir, 'bin'), dst=build_dir_src)
    config_file = os.path.join(src_dir, 'test', 'config.ini')
    shutil.copyfile(os.path.join(root_folder, 'config.ini'), config_file)
    with open(config_file) as f:
        c = f.read() \
        .replace('__BUILDDIR__', build_dir) \
        .replace('__SRCDIR__', src_dir)
    with open(config_file, 'w') as f:
        f.write(c)

    print('src dir:')
    print(src_dir)
    print('build dir:')
    print(build_dir)

if __name__ == "__main__":
    main()
