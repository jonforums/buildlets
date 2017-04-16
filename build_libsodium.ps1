#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2017-04-16 10:55:54 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='libsodium version to build (eg - 1.0.12)')]
  [validateset('1.0.12')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

$libname = 'libsodium'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = "https://download.${libname}.org/${libname}/releases/"
$archive = "${repo_root}${source}"
$hash_uri = "https://raw.github.com/jonforums/buildlets/master/hashery/${libname}.sha1"

# source the buildlet library
. "$PWD\buildlet_utils.ps1"

# download source archive
Fetch-Archive

# download hash data and validate source archive
Validate-Archive

# extract
Extract-Archive

# patch, configure, build, archive
Push-Location "${source_dir}"

  # activate toolchain
  Activate-Toolchain {
    # Work around libtool's well known behavior of dropping flags like -static-libgcc
    # that it doesn't currently understand.
    #   http://www.gnu.org/software/libtool/manual/libtool.html#Stripped-link-flags
    $env:CC = 'gcc -static-libgcc'
  }

  # configure
  Configure-Build {
    # TODO make libwinpthread a static dependency like libgcc
    sh -c "./configure --prefix=${install_dir} ${triplets} --without-pthreads" | Out-Null
  }

  # build
  New-Build {
    sh -c "make" | Out-Null
  }

  # TODO add `make check` step

  # install
  sh -c "make install" | Out-Null

  # archive
  Archive-Build

Pop-Location

# cleanup
Clean-Build
