#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2020-09-26 16:52:35 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='Discount version to build (eg - 2.2.7)')]
  [validateset('2.2.7')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

# project documentation: http://www.pell.portland.or.us/~orc/Code/discount/
$libname = 'discount'
$source = "${libname}-${version}.tar.gz"
$build_name = "${libname}-${version}"
$repo_root = "https://github.com/Orc/${libname}/archive/"
$archive = "${repo_root}v${version}.tar.gz"
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
  Activate-Toolchain {
    $env:CC = 'gcc'
    $env:CFLAGS = '-s -O2'
  }

  # configure
  Configure-Build {
    sh -c "./configure.sh --prefix=${install_dir} --enable-dl-tag --enable-superscript" | Out-Null
  }

  # build
  New-Build {
    sh -c "make" | Out-Null
  }

  # install
  sh -c "make install" | Out-Null

  # archive
  Archive-Build

Pop-Location

# cleanup
Clean-Build
