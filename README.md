[![Import](https://cdn.infobeamer.com/s/img/import.png)](https://info-beamer.com/use?url=https://github.com/info-beamer/package-hd-player)

# Description

A very simple media player that can display FullHD videos as well as PNG/JPEG images.

# Example usage

You can use this Package to display a bunch of images. Upload the images using
the assets page. Then create a new Setup based on this Package. To do that, go to
the packages page, select the **HD Player** Package and then click the **Create Setup**
button. Give your new Setup a name.

The configuration screen for your new Setup allows you to specify which assets
you want to play. Click the **Add item** Button for each Asset you want to play.
In the new row that appears, select the **Asset** field. Delete the default
value (empty.png) and select the image you previously uploaded.

When done, click save. Your Setup is now ready for your Device.

# Settings

## Switch Time (switch_time)

Selects the duration of the fade to black effect that happens between media
files. You can choose from a set of different durations ranging from Instantly
(the is no visible effect) to 0.8 seconds.

## Rotation (rotation)

You can rotate the content in 90 degree increments so it plays
correctly on portrait or landscape screens.

## Progress indicator (progress)

Displays an optional progress indicator that allows viewers to see how
long the current content will be shown on the screen.

## Synchronized Start (synced)

Allows you to play one or multiple playlist synchronized accross multiple
devices. If you play the same playlist or different playlists of the same total
play time on multiple devices, the start time for each asset will be calculated
based on the current time. Play lists with a length of (for example) 10 seconds
will start at every full minute, every 10 seconds past the full minute and so
on. Since every device can calculate the start time solely based on the current
time and the playlist length, no network connection is required between devices.

## Ken Burns effect for images (kenburns)

Uses the [Ken Burns effect](https://en.wikipedia.org/wiki/Ken_Burns_effect) for
all images displayed.  Each image will slowly pan and zoom while it is
displayed. The movement is chosen randomly from a predefined set.

## Play audio (audio)

Play audio track for all video files. By default the playback is silent.

# Running outside of info-beamer hosted

All info-beamer hosted packages can be run with the standalone
info-beamer pi program with a little (or a little more) work. All
you have to do for this packages is to create a `config.json` file.

Have a look at [the advanced documentation](ADVANCED.md) for
more information about this and other options possible.

# Offline

You cannot use the [Synchronized start](#synced) feature offline as
it requires a precise system time across multiple devices. This usually
requires network access to reach an NTP server.

## Problems?

Please report any problems you encounter using this package here:

https://github.com/info-beamer/package-hd-player/issues

# Changelog

## Version 2021-10-18

Fixed synced playback when using HEVC videos. Synchronize Ken Burns effect.

## Version 2019-11-06.hevc

This package can now play HEVC videos with up to 4K resolution on the Pi4.
Right now only a single HEVC decoder can be used at the same time. This
prevents the player from seamlessly switching between videos. Instead it
has to pause for a brief moment (with a black screen) while it's loading
the next video. This might be solved in a future version of info-beamer.

## Version 2019-08-22

Now compatible with the Pi4
