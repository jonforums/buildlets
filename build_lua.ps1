#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2014-05-08 21:35:09 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='lua version to build (eg - 5.2.3)')]
  [validateset('5.2.1','5.2.2','5.2.3')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

$libname = 'lua'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = "http://www.lua.org/ftp/"
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
    $maj_min = ($version -split '\.')[0..1] -join ''
    $script:to_bin = 'lua.exe','luac.exe',"lua${maj_min}.dll"
    $script:to_inc = 'lua.h','luaconf.h','lualib.h','lauxlib.h','lua.hpp'
    $script:to_lib = 'liblua.a'
  }

  # build
  New-Build {
    Push-Location src
      sh -c "make mingw" | Out-Null
    Pop-Location
  }

  # install
  Push-Location src
    New-Item "$install_dir/bin","$install_dir/include","$install_dir/lib" -itemtype directory | Out-Null
    mv $to_bin "$install_dir/bin"
    mv $to_inc "$install_dir/include"
    mv $to_lib "$install_dir/lib"
    mv (Resolve-Path ../doc) "$install_dir"
  Pop-Location

  # archive
  Archive-Build

Pop-Location

# cleanup
Clean-Build
