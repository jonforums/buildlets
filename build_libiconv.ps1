#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-11-10 14:41:48 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='libiconv version to build (eg - 1.14)')]
  [validateset('1.14')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

$libname = 'libiconv'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = "http://ftp.gnu.org/pub/gnu/${libname}/"
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
    # FIXME config.guess cannot guess system type
    if ($x64) { $triplets = '--build=x86_64-w64-mingw32' }
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

  # hoist binary archive to top level
  Move-ArchiveToRoot

Pop-Location

# cleanup
Clean-Build
