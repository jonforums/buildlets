#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2016-11-10 12:01:54 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='libyaml version to build (eg - 0.1.7)')]
  [validateset('0.1.7')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

$libname = 'libyaml'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = "https://github.com/yaml/${libname}/archive/"
$archive = "${repo_root}${version}.tar.gz"
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
    $env:CFLAGS = '-g -O2 -DYAML_DECLARE_EXPORT'
  }

  # patch
  Apply-Patches

  # configure
  Configure-Build {
    sh -c "autoreconf -fvi" | Out-Null
    sh -c "./configure --prefix=${install_dir} ${triplets}" | Out-Null
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
