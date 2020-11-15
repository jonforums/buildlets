#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2020-11-15 09:30:05 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='Oniguruma version to build (eg - 6.9.6)')]
  [validateset('6.9.6')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

$libname = 'onig'
$source = "${libname}-${version}.tar.gz"
$build_name = "${libname}-$($version.Split([char[]]'-_')[0])"
$repo_root = "https://github.com/kkos/oniguruma/releases/download/v$($version.Replace('-','_'))/"
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
    sh -c "./configure --prefix=${install_dir} $triplets" | Out-Null
  }

  # build
  New-Build {
    sh -c 'make' | Out-Null
  }

  # install
  sh -c 'make install-strip' | Out-Null

  # archive
  Archive-Build

Pop-Location

# cleanup
Clean-Build
