# Copyright (c) 2019 Federico Kircheis

# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.


# FIXME: something more like mktemp with template would be better
function New-TemporaryDirectory {
  $parent = [System.IO.Path]::GetTempPath()
  [string] $name = [System.Guid]::NewGuid()
  $dir=(Join-Path $parent $name);
  New-Item -ItemType Directory -Path $dir | Out-Null
  $dir;
}

function get_config_dir() {
  if ($env:XDG_CONFIG_HOME) {
    return "$env:XDG_CONFIG_HOME/tmpfox";
  }
  if ($env:LOCALAPPDATA) {
    return "$env:LOCALAPPDATA/tmpfox";
  }
  return "$env:HOME/.config/tmpfox";
}

function get_browser_settings([string] $SETTINGS) {
  Get-Content -Path "$SETTINGS";
}

function get_default_settings {
  # default settings should leave the browser in a state when someone can use it immediately
  # - do not open multiple tabs
  # - avoid welcome screens
  # - avoid tutorials
  # check https://ffprofile.com/
  'user_pref("browser.shell.checkDefaultBrowser", false);'
  # 'user_pref("extensions.autoDisableScopes", 14);' # do not open page of newly installed plugins, but also disables them...
  'user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);' # privacy notice

  # otherwise asks if OK to close all tabs/windows
  'user_pref("browser.sessionstore.warnOnQuit", false);'
  'user_pref("browser.warnOnRestart", false);'
  'user_pref("browser.tabs.warnOnClose", false);'

  # do not install other things in tmpfox, eases reproducibility
  'user_pref("experiments.activeExperiment", false);'
  'user_pref("experiments.enabled", false);'
  'user_pref("experiments.manifest.uri", "");'
  'user_pref("experiments.supported", false);'
  'user_pref("network.allow-experiments", false);'
  'user_pref("app.shield.optoutstudies.enabled", false);'

  # respect $WWW_HOME, but only if present
  if ($env:WWW_HOME) {
    'user_pref("browser.startup.homepage", "{0}");' -f "$env:WWW_HOME"
    'user_pref("startup.homepage_welcome_url", "{0}");' -f "$env:WWW_HOME"
  }
}

# FIXME: there seem no to be any equivalent utility as zipgrep, user must ensure correct file name
function copy_extension([string]  $CONFIG_DIR_extensions, [string] $PROFILEDIR_extensions) {
  New-Item -Path $PROFILEDIR_extensions -ItemType Directory | Out-Null;
  Copy-Item -Path $CONFIG_DIR_extensions/*xpi -Destination $PROFILEDIR_extensions;
}

function is_help_param([string] $1) {
  return ("$1" -eq "-h") -or ("$1" -eq "--help") -or ("$1" -eq "h") -or ("$1" -eq "help") -or ("$1" -eq "?" ) -or
         ("$1" -eq "/h") -or ("$1" -eq "/help") -or ("$1" -eq "/?" );
}

# FIXME: check https://stackoverflow.com/questions/4644470/from-command-line-how-to-know-which-firefox-version-is-installed-in-windows-lin
# and check alternatives for grep and sed
function help() {
  'tmpfox options'
  'Usage: tmpfox [ options ... ] [URL]'
}

function version() {
  'tmpfox version 0.1'
  'based on: '
  (& 'C:\Program Files\Mozilla Firefox\firefox.exe' --version | more)[0]
}

# FIXME: make to function that takes all arguments
# declaring it, as it is commented out, causes issues with parameters with whitespace
#function main {
  [string] $PROFILEDIR = New-TemporaryDirectory;

  try {
    $PROFILEDIR_SETTINGS = $PROFILEDIR.replace('\','\\');

    $CONFIG_DIR=(get_config_dir);
    $SETTINGS="$CONFIG_DIR/user_pref";
    $DEFAULT_SETTINGS=$true;

    $PARSE=$true;
    $NEXT_IS_SETTINGS_FILE=$false;

    $ffargs=@()
    foreach ($key in $args) {
      # $first, $rest= $arr
      if( ! $PARSE ){
        $ffargs += "`"$key`"";
      } else {
        if($NEXT_IS_SETTINGS_FILE) {
          $SETTINGS="$key"; $NEXT_IS_SETTINGS_FILE=$false;
        } elseif($key -eq "--settings-files") {
          $NEXT_IS_SETTINGS_FILE=$true;
        } elseif($key -eq "--no-default-settings") {
          $DEFAULT_SETTINGS=$false;
        } elseif(is_help_param "$key") {
          help;
          exit 0;
        } elseif( ($key -eq "-v") -or ($key -eq "--version") -or ($key -eq "/v") -or ($key -eq "/version") ) {
          version;
          exit 0;
        } else {
          $ffargs += "`"$key`"";
        }
        if($key -eq "--") {
          $PARSE=$false;
        }
      }
    }

    if($DEFAULT_SETTINGS) {
      Set-Content -Path "$PROFILEDIR/user.js" -Value (get_default_settings);
      Add-Content -Path "$PROFILEDIR/user.js" -Value "user_pref(`"browser.cache.disk.parent_directory`", `"$PROFILEDIR_SETTINGS`");";
    }
    if (Test-Path -PathType Leaf -Path $SETTINGS) {
      Add-Content -Path "$PROFILEDIR/user.js" -Value (get_browser_settings $SETTINGS);
    }

    copy_extension "$CONFIG_DIR/extensions/" "$PROFILEDIR/extensions/"

    Start-Process -Wait -FilePath 'C:\Program Files\Mozilla Firefox\firefox.exe' -WorkingDirectory $env:Temp -ArgumentList (@("-profile","`"$PROFILEDIR`"","--no-remote","--new-instance") + $ffargs)
  } finally {
    sleep 1 # leave some time to ensure all files are relased
    Remove-Item -Path "$PROFILEDIR" -Recurse -ErrorAction SilentlyContinue
  }
#}

#main $args
