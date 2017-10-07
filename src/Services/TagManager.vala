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
        static TagManager _instance = null;
        public static TagManager instance {
            get {
                if (_instance == null) {
                    _instance = new TagManager ();
                }
                return _instance;
            }
        }

        public signal void discovered_new_item (PlayMyMusic.Objects.Artist artist, PlayMyMusic.Objects.Album album, PlayMyMusic.Objects.Track track);
        public signal void discover_started ();
        public signal void discover_finished ();

        Gst.PbUtils.Discoverer discoverer;

        int discover_counter = 0;

        string unknown = _("Unknown");

        construct {
            try {
                discoverer = new Gst.PbUtils.Discoverer ((Gst.ClockTime) (5 * Gst.SECOND));
                discoverer.start ();
                discoverer.discovered.connect (discovered);
            } catch (Error err) {
                warning (err.message);
            }
        }

        private void discovered (Gst.PbUtils.DiscovererInfo info, Error err) {
            new Thread<void*> (null, () => {
                if (info.get_result () != Gst.PbUtils.DiscovererResult.OK) {
                    warning ("DISCOVER ERROR: '%d' %s %s\n(%s)", err.code, err.message, info.get_result ().to_string (), info.get_uri ());
                } else {
                    var tags = info.get_tags ();
                    if (tags != null) {
                        string uri = info.get_uri ();
                        uint64 duration = info.get_duration ();
                        File f = File.new_for_uri (uri);
                        string path = f.get_path ();

                        string o;
                        GLib.Date? d;
                        Gst.DateTime? dt;
                        uint u;
                        uint64 u64 = 0;

                        // TRACK REGION
                        var track = new PlayMyMusic.Objects.Track ();
                        track.duration = duration;
                        track.path = path;
                        if (tags.get_string (Gst.Tags.TITLE, out o)) {
                            track.title = o;
                        }
                        if (track.title.strip () == "") {
                            track.title = f.get_basename ();;
                        }

                        if (tags.get_uint (Gst.Tags.TRACK_NUMBER, out u)) {
                            track.track = (int)u;
                        }
                        if (tags.get_uint (Gst.Tags.ALBUM_VOLUME_NUMBER, out u)) {
                            track.disc = (int)u;
                        }
                        if (tags.get_string (Gst.Tags.GENRE, out o)) {
                            track.genre = o;
                        }
                        if (track.duration == 0 && tags.get_uint64 (Gst.Tags.DURATION, out u64)) {
                            track.duration = u64;
                        }

                        // ALBUM REGION
                        var album = new PlayMyMusic.Objects.Album ();
                        if (tags.get_string (Gst.Tags.ALBUM, out o)) {
                            album.title = o;
                        }

                        if (album.title.strip () == "") {
                            f = f.get_parent ();
                            if (f != null) {
                                album.title = f.get_basename ();
                            } else {
                                album.title = unknown;
                            }
                        }

                        if (tags.get_date_time (Gst.Tags.DATE_TIME, out dt)) {
                            if (dt != null) {
                                album.year = dt.get_year ();
                            } else if (tags.get_date (Gst.Tags.DATE, out d)) {
                                if (d != null) {
                                    album.year = dt.get_year ();
                                }
                            }
                        }

                        // ARTIST REGION
                        var artist = new PlayMyMusic.Objects.Artist ();
                        if (tags.get_string (Gst.Tags.ALBUM_ARTIST, out o)) {
                            artist.name = o;
                        } else if (tags.get_string (Gst.Tags.ARTIST, out o)) {
                            artist.name = o;
                        }

                        if (artist.name.strip () == "") {
                            f = f.get_parent ();
                            if (f != null) {
                                artist.name = f.get_basename ();
                            } else {
                                artist.name = unknown;
                            }
                        }

                        discovered_new_item (artist, album, track);
                    }
                }

                discover_counter--;
                if (discover_counter == 0) {
                    discover_finished ();
                }
                return null;
            });
        }

        public void add_discover_path (string path) {
            if (discover_counter == 0) {
                discover_started ();
            }
            discover_counter++;
            File f = File.new_for_path (path);
            discoverer.discover_uri_async (f.get_uri ());
        }
    }
}
