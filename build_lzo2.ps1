#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2020-09-26 18:01:27 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='lzo2 version to build (eg - 2.10)')]
  [validateset('2.10')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

$libname = 'lzo'
$source = "${libname}-${version}.tar.gz"
$build_name = "${libname}-${version}"
$repo_root = "https://www.oberhumer.com/opensource/lzo/download/"
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
Push-Location "${build_src_dir}"

  # activate toolchain
  Activate-Toolchain

  # configure
  Configure-Build {
    sh -c "./configure --prefix=${install_dir} ${triplets}" | Out-Null
  }

  # build
  New-Build {
    sh -c "make" | Out-Null

    # build static minilzo library
    sh -c "gcc -g -Wall -Wextra -O2 -Iinclude/lzo -c minilzo/minilzo.c -o minilzo/minilzo.o" | Out-Null
    sh -c "ar rcs minilzo/libminilzo.a minilzo/minilzo.o" | Out-Null
  }

  # install
  sh -c "make install" | Out-Null
  cp "minilzo/libminilzo.a" "${install_dir}/lib" | Out-Null
  cp "minilzo/minilzo.h" "${install_dir}/include/lzo" | Out-Null

  # archive
  Archive-Build

Pop-Location

# cleanup
Clean-Build
