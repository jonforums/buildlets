#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2014-06-29 11:41:27 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='libffi version to build (eg - 3.1)')]
  [validateset('3.0.11','3.0.12','3.0.13','3.1')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

$libname = 'libffi'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = "ftp://sourceware.org/pub/${libname}/"
$archive = "${repo_root}${source}"
$hash_uri = "https://raw.github.com/jonforums/buildlets/master/hashery/${libname}.md5"

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
  Activate-Toolchain

  # configure
  Configure-Build {
    sh -c "./configure --prefix=${install_dir} ${triplets}" | Out-Null
  }

  # build
  New-Build {
    sh -c "make" | Out-Null
  }

  # install
  sh -c "make install" | Out-Null

  # post-install patch
  Push-Location "$install_dir"
    mv $(Resolve-Path lib\libffi-*\include) $PWD
    rm $(Resolve-Path lib\libffi-*)
  Pop-Location

  # archive
  Archive-Build

Pop-Location

# cleanup
Clean-Build
