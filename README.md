[![Import](https://cdn.infobeamer.com/s/img/import.png)](https://info-beamer.com/use?url=https://github.com/info-beamer/package-hd-player)

# Description

A very simple media player that can display FullHD or 4K videos as well as PNG/JPEG images.

# Example usage

You can use this package to display a videos and images in a loop. Upload your assets
using the "Assets" section. Then create a new setup based on this package. To do that, go to
the packages page, select the **HD Player** package and then click the **Create setup**
button. Give your new setup a name.

The configuration screen for your new setup allows you to specify which assets
you want to play. Click the **Add item** button and select one or more videos or
images. They will be added to this setup's playlist.

Alternatively you can also add one or more native info-beamer playlists created
within the "Playlist" section in your account. Modifying the playlist will then update each
setup that uses this playlist.

Each item can be scheduled. Click on the calendar icon in the "Schedule" option of each
item to set a schedule. The schedule is based on the timezone configured for each device.
You can reconfigure a device's timezone in the device list by clicking on its timezone.

When done, click "Save". Your setup is now ready for your device.

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

Setting this to "Disabled" can improve video playback performance on Pi4
and Pi5 as this avoids rendering the necessary overlay. This can be helpful
for 4K videos with high framerates.

## Idle image (idle)

An image shown if nothing is scheduled (or if the playlist is empty) or
if synchronized playback is active and playback has to wait for the next
synced playback sync point.

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

# Offline

You cannot use the [Synchronized start](#synced) feature offline as
it requires a precise system time across multiple devices. This usually
requires network access to reach an NTP server.

## Problems?

Please report any problems you encounter using this package here:

https://github.com/info-beamer/package-hd-player/issues

# Changelog

## Version 2024-10-14

* Add support for scheduled items. You can either schedule individual
  items or embed playlists with items already scheduled.
* Added "idle image" that is shown if either nothing is scheduled or
  if synced playback is active and playback has to wait for the next
  sync point.

## Version 2024-08-04

HEVC videos are now gapless on the latest stable OS release v14. If you
run a mix of old and new OS releases, synced playback won't work: Ensure
all devices run the same OS release if you use synced playback.

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
