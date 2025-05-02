load("@prelude//toolchains:demo.bzl", "system_demo_toolchains")

# All the default toolchains, suitable for a quick demo or early prototyping.
# Most real projects should copy/paste the implementation to configure them.
system_demo_toolchains()

# https://github.com/nimble-code/Spin
http_file(
  name = 'spin_archive',
  urls = [
    'https://github.com/nimble-code/Spin/raw/refs/heads/master/Bin/spin651_mac64.gz',
  ],
  sha256 = 'd05199540b66f54764fdb7afd94287f11b0368a2f6b061c4afe0ffe0d3f64f77',
)

genrule(
  name = "spin_bin",
  out = "spin",
  executable = True,
  srcs = [
    ':spin_archive',
  ],
  cmd = "gunzip -c ${SRCS} > ${OUT} && chmod 755 ${OUT}",
  tests = [
    ':spin_check',
  ],
  visibility = ['PUBLIC'],
)

sh_test(
    name = "spin_check",
    test = ":spin_bin",
    args = ["-V"],
)

BATS_VERSION = '1.11.1'

http_archive(
  name = 'bats_archive',
  urls = [
    'https://github.com/bats-core/bats-core/archive/refs/tags/v{}.tar.gz'.format(BATS_VERSION),
  ],
  sha256 = '5c57ed9616b78f7fd8c553b9bae3c7c9870119edd727ec17dbd1185c599f79d9',
  type = 'tar.gz',
  sub_targets = {
    'bats': ["bats-core-{}/bin/bats".format(BATS_VERSION)],
  },
)

sh_binary(
  name = 'bats_bin',
  main = ':bats_archive[bats]',
  visibility = ['PUBLIC'],
)

# https://github.com/microsoft/pict
PICT_VERSION = '3.7.4'

http_archive(
  name = 'pict_archive',
  urls = [
    'https://github.com/microsoft/pict/archive/refs/tags/v{}.tar.gz'.format(PICT_VERSION),
  ],
  sha256 = '42af3ac7948d5dfed66525c4b6a58464dfd8f78a370b1fc03a8d35be2179928f',
  type = 'tar.gz',
  strip_prefix = 'pict-{}'.format(PICT_VERSION),
)

genrule(
  name = 'pict_bin',
  out = 'pict',
  executable = True,
  srcs = [
    ':pict_archive',
  ],
  cmd = 'rsync -av --copy-links pict_archive/ ${TMP}/; (cd ${TMP}; make pict); cp ${TMP}/pict ${OUT}',
  visibility = ['PUBLIC'],
)

export_file(
  name = 'convert_tsv_to_cucumber_table.go',
  visibility = ['PUBLIC'],
)

sh_binary(
  name = "aws_get_token",
  main = "aws_get_token.py",
  visibility = ['PUBLIC'],
)

export_file(
  name = "gradle_collect_module_info.init.gradle.kts",
  visibility = ['PUBLIC'],
)
