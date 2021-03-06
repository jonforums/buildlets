#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2017-03-26 00:44:02 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='ragel version to build (eg - 6.10)')]
  [validateset('6.10')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

$libname = 'ragel'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = "http://www.colm.net/files/${libname}/"
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
  Activate-Toolchain

  # configure
  Configure-Build {
    $cfg_args = @("--prefix=${install_dir}",
                  "LDFLAGS='-static-libgcc -static-libstdc++'")

    sh -c "./configure $($cfg_args -join ' ') ${triplets}" | Out-Null
  }

  # build
  New-Build {
    sh -c "make" | Out-Null
  }

  # staging
  Stage-Build {
    sh -c "make install-strip" | Out-Null
  }

  # archive
  Archive-Build

Pop-Location

# cleanup
Clean-Build
