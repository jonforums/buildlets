#requires -version 2.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-03-24 15:38:43 -0600
#
# TODO:
#   - extract generics into a downloadable utils helper module
#   - support x64 builds (configure's --enable-64bit)

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='TclTk version to build (eg - 8.6.0)')]
  [validateset('8.5.13','8.6.0')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='Path to DevKit root directory')]
  [string] $devkit = $nil
)

$sources = @{tcl = "tcl${version}-src.tar.gz"; tk = "tk${version}-src.tar.gz"}
$repo_root = 'http://prdownloads.sourceforge.net/tcl/'
$archives = @{tcl = "${repo_root}$($sources.tcl)"; tk = "${repo_root}$($sources.tk)"}
$hash_uris = @{tcl = "https://raw.github.com/jonforums/buildlets/master/hashery/tcl.sha1";
               tk = "https://raw.github.com/jonforums/buildlets/master/hashery/tk.sha1"}

# download and source the buildlet library
if (-not (Test-Path "$PWD\buildlet_utils.ps1")) {
  Write-Host '---> fetching buildlet library' -foregroundcolor yellow
  try {
    $fetcher = New-Object System.Net.WebClient
    $fetcher.DownloadFile('https://raw.github.com/jonforums/buildlets/master/buildlet_utils.ps1',
                          "$PWD\buildlet_utils.ps1")
  }
  catch {
    throw '[ERROR] unable to fetch required buildlet library'
  }
}
. "$PWD\buildlet_utils.ps1"

# download, validate, and extract source archives
# download source archives
if (-not ((Test-Path $sources.tcl) -and (Test-Path $sources.tk))) {
  foreach ($k in $archives.keys) {
    $source = $sources[$k]
    $archive = $archives[$k]
    Fetch-Archive
  }
}

# download hash data and validate source archives
foreach ($k in $archives.keys) {
  $source = $sources[$k]
  $hash_uri = $hash_uris[$k]
  Validate-Archive
}

# extract
foreach ($k in $archives.keys) {
  $source = $sources[$k]
  Extract-Archive
}

# patch, configure, build, archive
foreach ($source_dir in "tcl${version}", "tk${version}") {
  Push-Location $source_dir/win

    # activate toolchain
    Activate-Toolchain

    # configure
    Write-Status "configuring $source_dir"
    $clean_pwd = $(Split-Path $PWD -parent).Replace('\','/')
    $install_dir = "$clean_pwd/my_install"
    $cfg_args = "--prefix=$install_dir --enable-threads"
    if ($source_dir -match '^tcl') { $tcl_build_dir = "$clean_pwd/win" }
    if ($source_dir -match '^tk') { $cfg_args += " --with-tcl=$tcl_build_dir" }
    sh -c "./configure $cfg_args" | Out-Null

    # build
    Write-Status "building $source_dir"
    sh -c "make" | Out-Null

    # install
    sh -c "make install" | Out-Null

    # archive
    Archive-Build

    # hoist binary archive to top level
    Move-ArchiveToRoot

  Pop-Location
}

# cleanup
Write-Status "cleaning up"
foreach ($dir in "tcl${version}", "tk${version}") { rm $dir -recurse -force }
