# Pyrrha: Daughter of Pandora

Daughter of Pandora, Survivor of the Flood, Logitech Media Server plugin.

## Disclaimer

This is beta software, currently at a proof-of-concept stage.
_Use at your own risk._

This plugin is not approved by Pyrrha's mother, and as such, its use may
not be tolerated.  _Invite the wrath of the Gods at your own risk._

## Limitations

- Fetches your station list and plays your stations
- But requires an annual tribute to Pyrrha's mother
- Does not support account management
- Does not support station curation
- Does not allow skips

Pyrrha has been tested with LMS 8.3.1 running in a docker container with
playback directed at the Local Player plugin, and with LMS 8.3.0 and
squeezelite running under piCorePlayer on a pair of Raspberry Pis.

## Installation

1. In LMS, navigate to the plugin settings page.  Near the bottom, find the
   **Additional Repositories** section.  Add this URL as an additional
   third-party extension repository:
   https://github.com/sspiff/lms-plugin-pyrrha/releases/download/repo-stable/repo.xml
2. After some time (or perhaps an LMS restart), refresh that same plugin
   settings page.  Near the bottom, you should now have a Pyrrha section.
   Check the box to enable the Pyrrha plugin, and restart LMS.
3. With LMS restarted, navigate to Pyrrha's settings page, and enter your
   username and password.
4. You can find Pyrrha on the LMS home page under **My Apps**.

## Development

From the root of the git repository, a simple ```make``` should produce
the plugin zip and repo xml, both of which will be output to ```obj/dist/```.

The plugin version baked into the build artifacts by the ```Makefile```
is determined by ```git describe```.  Use ```git tag -a``` to set the text
returned by ```describe```.

Note that the ```Makefile``` uses some archaic magic.  The incantations
are known to work on a Mac with the xcode cli tools installed.

The Inkscape source for the icon can be found under ```misc/```.

## Acknowledgements

Thank you to the [forum](https://forums.slimdevices.com/) users for their
encouragement and support.

Pyrrha was heavily influenced by the standard plugins in the
[Logitech Media Server](https://github.com/Logitech/slimserver).
After all, the apple falls not far from the
[tree](https://github.com/Logitech/slimserver/tree/public/8.4/Slim/Plugin/Pandora).

Pyrrha contains the following 3rd-party perl modules
(see [3RDPARTY](3RDPARTY.md)):
```Crypt::Blowfish_PP```, ```Crypt::ECB```, ```JSON```,
and ```WebService::Pandora```.

