# Advanced options possible with this package

## Running in standalone mode with info-beamer pi

All info-beamer hosted packages can be run with the standalone info-beamer
pi program with a little (or a little more) works.  All you have to do for
this packages is to create a `config.json` file.

Put all your images/videos into the package directory (next to the
node.lua file, then run the `mkconfig` python script to create a
`config.json` that will play them. The `mkconfig` script is an
example of how to create such a `config.json`. You might want to
adapt the file or take a whole different approach.

You'll need to install the `avprobe` tool before running `mkconfig` as
that's used the detect the duration of video files.

By default images are shown for 5 seconds. Change the `IMAGE_DURATION`
value to change that.

Once done, just run info-beamer in the package directory like this:

```
$ info-beamer .
```

## Delivering assets through the package itself

You might want to use this package through info-beamer hosted to show
automatically updating content. In that case you probably already have some
kind of preprocessing step running locally that produces images or videos.

You can use this package, your assets and combine it with a custom
configuration file that references these assets. If you add, change or
remove assets you don't have to use the configuration interface on the
hosted website. Instead you just change the file `static-config.json` in
the package itself. It overwrites settings made through the configuration
interface.

Here's how a complete setup might look like: First you have to clone
this package from github:

```
$ git clone https://github.com/info-beamer/package-hd-player.git
```

Then add your videos and images to the package directory:

```
$ cd package-hd-player
$ cp /some/images/*.jpg /some/videos/*.mp4 .
```

Finally create the file `static-config.json`. You can use the included
script `mkconfig` (see above) for that:

```
$ mkconfig static-config.json
```

This will create a `static-config.json` file that references all
your assets. You can now try to run this directory using info-beamer pi
like this:

```
$ info-beamer .
```

You should see your content. Now it's time to import this directory into
info-beamer hosted to make it trivial to update any number of devices.
We're using the [MANIFEST method](https://info-beamer.com/packages) in
this example:

```
$ ls > MANIFEST
```

This should give you a file named `MANIFEST` with all filenames in the
current directory. Copy the complete directory to a publically reachable
webserver now. This example assumes the the uploaded MANIFEST file is
reachable at `http://example.net/info-beamer/MANIFEST`. On
https://info-beamer.com/packages click on "Add Package" > "Create from
Url...". Enter the Url `http://example.net/info-beamer/MANIFEST` and click
on "Import". info-beamer hosted will import all files into your account and
create a new package for you. You can now create a setup based on this
package and install that on your devices. Notice that you can't use the
setup configuration interface as all settings made there are overwritten by
the file `static-config.json` included in the package.

If you update files, redo the `mkconfig`/`MANIFEST` step and then call the
"Update webhook Url" you can find on the package page.

## Adding intermission screens

Similar to the previous example it is also possible to add assets to your
package and have them scheduled during a fixed time interval. Just include
the file `intermission.json` or `intermission-<serial>.json` (where serial
is the serial number of the Pi) to show intermissions that interrupt the
normal show with custom images/videos.

The file format for the `intermission.json` files is similar to the
`config.json` file:

```
[
    {
        "starts": 0,
        "ends": 2000000000,
        "asset_name": "example.jpg",
        "type": "image",
        "duration": 4
    }, {
        ...
    }
]
```

It's a list of objects. Each object describes a single intermission with
its own start/end time given as a [unix timestamp](https://en.wikipedia.org/wiki/Unix_time).
The `asset_name` must reference an asset included in the package itself.
`type` can be either `"video"` or `"image"`. Duration is the duration of a
single loop for your item. Don't make the duration too long, as the player
will play each iteration for it's full duration. The hd-player never
interrupts a currently playing asset.

If multiple intermissions are active they will all play one after the
other. An existing `intermission-<serial>.json` file will overwrite an
`intermission.json` file.

Be sure to disable (set to false) the `synced` flag in `config.json` as
synced playback doesn't work well with playlists of dynamic duration.

## Need help?

Get in [contact](https://info-beamer.com/contact).
