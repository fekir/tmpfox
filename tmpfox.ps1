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
  New-Item -ItemType Directory -Path (Join-Path $parent $name) | Out-Null
  (Join-Path $parent $name);
}

function get_default_settings{
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

  if ($env:WWW_HOME) {
    'user_pref("browser.startup.homepage", "{0}");' -f "$env:WWW_HOME"
    'user_pref("startup.homepage_welcome_url", "{0}");' -f "$env:WWW_HOME"
  }
}

function main {
  [string] $PROFILEDIR = New-TemporaryDirectory;

  try {
    Set-Content -Path "$PROFILEDIR/prefs.js" -Value (get_default_settings)
    $PROFILEDIR_SETTINGS = $PROFILEDIR.replace('\','\\');
    Add-Content -Path "$PROFILEDIR/prefs.js" -Value "user_pref(`"browser.cache.disk.parent_directory`", `"$PROFILEDIR_SETTINGS`");"

    $ffargs=@("-profile","`"$PROFILEDIR`"","--no-remote","--new-instance")
    foreach ($arg in $args) {
      $ffargs += $arg
    }
    Start-Process -Wait -FilePath 'C:\Program Files\Mozilla Firefox\firefox.exe' -WorkingDirectory $env:Temp -ArgumentList $ffargs
  } finally {
    Remove-Item -Path "$PROFILEDIR" -Recurse -ErrorAction SilentlyContinue
  }
}

main $args
