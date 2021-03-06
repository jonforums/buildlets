﻿#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2021-06-19 17:01:12 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='sqlite version to build (eg - 3.36.0).')]
  [validateset('3.36.0')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

# munge identifiers due to sqlite's unnecessarily complex naming schemes
[int[]] $v = $version.Split('.')
$sqlite_version = $v[0]*1000000 + $v[1]*10000 + $v[2]*100
if ($v.Length -eq 4) { $sqlite_version += $v[3] }
$sqlite_dirs = @{'3.36.0' = '2021'}

$libname = 'sqlite'
$source = "${libname}-amalgamation-${sqlite_version}.zip"
$build_name = "${libname}-amalgamation-${sqlite_version}"
$repo_root = "https://www.sqlite.org/$($sqlite_dirs[$version])/"
$archive = "${repo_root}${source}"
$hash_uri = "https://raw.github.com/jonforums/buildlets/master/hashery/${libname}.sha1"

# source the buildlet library
. "$PWD\buildlet_utils.ps1"

# download source archive
Fetch-Archive

# download hash data and validate source archive
Validate-Archive

# extract
Extract-CustomArchive {
  & "$s7z" "x" $source -o"${build_root}" | Out-Null
}

# patch, configure, build, archive
Push-Location "${build_src_dir}"

  # activate toolchain
  Activate-Toolchain

  # configure tools
  Configure-Build {
    $defines = @('-D_WIN32_WINNT=0x0A00'
                 '-DWINVER=0x0A00'
                 '-DNDEBUG'
                 '-D_WINDOWS'
                 '-DNO_TCL'
                 '-DSQLITE_ENABLE_MATH_FUNCTIONS'
                 '-DSQLITE_OMIT_DEPRECATED'
                 '-DSQLITE_ENABLE_JSON1'
                 '-DSQLITE_WIN32_MALLOC'
                 '-D__USE_MINGW_ANSI_STDIO'
                 '-DSQLITE_ENABLE_FTS4'
                 '-DSQLITE_ENABLE_FTS5'
                 '-DSQLITE_SECURE_DELETE'
                 '-DSQLITE_ENABLE_RTREE'
                 '-DSQLITE_ENABLE_GEOPOLY'
                 '-DSQLITE_DQS=0'
                 '-DSQLITE_THREADSAFE=0'
                 '-DSQLITE_MAX_EXPR_DEPTH=0'
                 '-DSQLITE_DEFAULT_MEMSTATUS=0'
                 '-DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1'
                 '-DSQLITE_LIKE_DOESNT_MATCH_BLOBS'
                 '-DSQLITE_OMIT_PROGRESS_CALLBACK'
                 '-DSQLITE_OMIT_SHARED_CACHE'
                 '-DSQLITE_ENABLE_DBSTAT_VTAB'
                 '-DSQLITE_ENABLE_BATCH_ATOMIC_WRITE'
                 '-DSQLITE_ENABLE_EXPLAIN_COMMENTS'
                 '-DSQLITE_ENABLE_COLUMN_METADATA'
                 '-DSQLITE_ENABLE_UNKNOWN_SQL_FUNCTION')
    $script:cflags = "-g $($defines -join ' ') -Wall -Wextra -O2 -march=native -pipe"
  }

  New-Build {
    $script:lib = "${libname}3"

    # static lib
    sh -c "gcc $cflags -c ${lib}.c -o ${lib}.o" | Out-Null
    sh -c "ar rcs lib${lib}.a ${lib}.o" | Out-Null

    # DLL
    sh -c "gcc -shared -static-libgcc -Wl,--output-def,${lib}.def -Wl,--out-implib,lib${lib}.dll.a -o ${lib}.dll ${lib}.o" | Out-Null

    # CLI
    sh -c "gcc -s $cflags shell.c -L. -Wl,-Bstatic -l${lib} -Wl,-Bdynamic -o ${lib}.exe" | Out-Null
  }

  # stage
  Stage-Build {
    New-Item "$install_dir/bin","$install_dir/include","$install_dir/lib" `
              -itemtype directory | Out-Null

    mv "${lib}.exe","${lib}.dll" "$install_dir/bin" | Out-Null
    mv "${lib}.h","${lib}ext.h" "$install_dir/include" | Out-Null
    mv "lib${lib}.a","lib${lib}.dll.a","${lib}.def" "$install_dir/lib" | Out-Null
  }

  # archive
  Archive-Build "${lib}-${version}"

Pop-Location

# cleanup
Clean-Build
