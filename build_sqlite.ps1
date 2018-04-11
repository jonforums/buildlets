#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2018-04-11 13:44:44 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='sqlite version to build (eg - 3.23.1).')]
  [validateset('3.22.0','3.23.1')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

# munge identifiers due to sqlite's unnecessarily complex naming schemes
[int[]] $v = $version.Split('.')
$sqlite_version = $v[0]*1000000 + $v[1]*10000 + $v[2]*100
if ($v.Length -eq 4) { $sqlite_version += $v[3] }
$sqlite_dirs = @{'3.22.0' = '2018'
                 '3.23.1' = '2018'}

$libname = 'sqlite'
$source = "${libname}-amalgamation-${sqlite_version}.zip"
$source_dir = "${libname}-amalgamation-${sqlite_version}"
$repo_root = "http://www.sqlite.org/$($sqlite_dirs[$version])/"
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
  & "$s7z" "x" $source | Out-Null
}

# patch, configure, build, archive
Push-Location "${source_dir}"

  # activate toolchain
  Activate-Toolchain

  # configure tools
  Configure-Build {
    $defines = @('-D_WIN32_WINNT=0x0501'
                 '-DNDEBUG'
                 '-D_WINDOWS'
                 '-DNO_TCL'
                 '-DSQLITE_ENABLE_JSON1'
                 '-DSQLITE_WIN32_MALLOC'
                 '-DSQLITE_ENABLE_FTS5'
                 '-DSQLITE_SECURE_DELETE'
                 '-DSQLITE_ENABLE_RTREE'
                 '-DSQLITE_THREADSAFE=1'
                 '-DSQLITE_MAX_EXPR_DEPTH=0'
                 '-DSQLITE_DEFAULT_MEMSTATUS=0'
                 '-DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1'
                 '-DSQLITE_LIKE_DOESNT_MATCH_BLOBS'
                 '-DSQLITE_ENABLE_EXPLAIN_COMMENTS'
                 '-DSQLITE_ENABLE_COLUMN_METADATA')
    $script:cflags = "-g $($defines -join ' ') -Wall -Wextra -O2"
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
