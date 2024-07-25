# Pyrrha: Daughter of Pandora

Daughter of Pandora, Survivor of the Flood, Lyrion Music Server plugin.

## Disclaimer

This plugin is not approved by Pyrrha's mother, and as such, its use may
not be tolerated.  _Invite the wrath of the Gods at your own risk._

## Limitations

- Fetches your station list and plays your stations
- Does not support account management
- Does not support station curation

Pyrrha has been tested with LMS 8.4.1 running in a docker container with
playback directed at the Local Player plugin, and with LMS 8.5.1 and
squeezelite running under piCorePlayer on a pair of Raspberry Pis.

## Usage

Pyrrha is now included in LMS's 3rd-party repositories.  To get started:

1. In LMS, navigate to the plugin settings page.  Find Pyrrha, check the
   box to enable it, and restart LMS.
2. With LMS restarted, navigate to Pyrrha's settings page, and enter your
   username and password.
3. You can find Pyrrha on the LMS home page under **My Apps**.

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
[Lyrion Music Server](https://github.com/LMS-Community/slimserver).
After all, the apple falls not far from the
[tree](https://github.com/LMS-Community/slimserver/tree/public/8.4/Slim/Plugin/Pandora).

Pyrrha contains the following 3rd-party perl modules
```Crypt::Blowfish_PP```, ```Crypt::ECB```, ```JSON```,
```Promise::ES6```, and ```WebService::Pandora```.
See [3RDPARTY](3RDPARTY.md).

