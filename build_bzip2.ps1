#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-11-10 14:41:30 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='bzip2 version to build (eg - 1.0.6)')]
  [validateset('1.0.6')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

$libname = 'bzip2'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = "http://www.bzip.org/${version}/"
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
    New-Item "$install_dir" -type directory | Out-Null
    $script:to_bin = 'bzip2.exe'
    $script:to_inc = 'bzlib.h'
    $script:to_lib = 'libbz2.a','libbz2.def'
    $script:to_doc = 'manual.html'
  }

  # build
  New-Build {
    sh -c "make bzip2 test" | Out-Null
  }

  # install
  New-Item "$install_dir/bin", "$install_dir/include", "$install_dir/lib", `
           "$install_dir/doc" -type directory | Out-Null
  cp $to_bin "$install_dir/bin"
  cp $to_inc "$install_dir/include"
  cp $to_lib "$install_dir/lib"
  cp $to_doc "$install_dir/doc"

  # archive
  Archive-Build

  # hoist binary archive to top level
  Move-ArchiveToRoot

Pop-Location

# cleanup
Clean-Build
