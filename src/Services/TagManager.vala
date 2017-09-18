/*-
 * Copyright (c) 2017-2017 Artem Anufrij <artem.anufrij@live.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * The Noise authors hereby grant permission for non-GPL compatible
 * GStreamer plugins to be used and distributed together with GStreamer
 * and Noise. This permission is above and beyond the permissions granted
 * by the GPL license by which Noise is covered. If you modify this code
 * you may extend this exception to your version of the code, but you are not
 * obligated to do so. If you do not wish to do so, delete this exception
 * statement from your version.
 *
 * Authored by: Artem Anufrij <artem.anufrij@live.de>
 */

namespace PlayMyMusic.Services {
    public class TagManager : GLib.Object {
        const int DISCOVERER_TIMEOUT = 5;
        static TagManager _instance = null;
        public static TagManager instance {
            get {
                if (_instance == null) {
                    _instance = new TagManager ();
                }
                return _instance;
            }
        }
        
        public signal void discovered_new_item (PlayMyMusic.Objects.Artist artist);

        construct {
        }

        public async void discover_tags (string path) {
            try {
                new Thread<void*>.try (null, () => {
                    try {
                        var file = GLib.File.new_for_path (path);
                        var discoverer = new Gst.PbUtils.Discoverer ((Gst.ClockTime) (5 * Gst.SECOND));
                        var info = discoverer.discover_uri (file.get_uri ());
                        var tags = info.get_tags ();

                        if (tags == null) {
                            return null;
                        }

                        string o;
                        // ARTIST REGION
                        var artist = new PlayMyMusic.Objects.Artist ();
                        if (tags.get_string (Gst.Tags.ALBUM_ARTIST, out o)) {
                            artist.name = o;
                        } else if (tags.get_string (Gst.Tags.ARTIST, out o)) {
                            artist.name = o;
                        }

                        // ALBUM REGION
                        var album = new PlayMyMusic.Objects.Album (artist);
                        if (tags.get_string (Gst.Tags.ALBUM, out o)) {
                            album.title = o;
                        }
                        artist.add_album (album);

                        // TRACK REGION
                        var track = new PlayMyMusic.Objects.Track ();
                        if (tags.get_string (Gst.Tags.TITLE, out o)) {
                            track.title = o;
                        }
                        album.add_track (track);

                        discovered_new_item (artist);

                    } catch (Error err) {
                        warning ("%s\npath: %s\n", err.message, path);
                    }
                    return null;
                });
            } catch (Error err) {
                warning (err.message);
            }
        }
    }
}
