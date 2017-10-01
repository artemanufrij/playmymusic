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

namespace PlayMyMusic.Objects {
    public class TracksContainer : GLib.Object {
        protected PlayMyMusic.Services.LibraryManager library_manager;

        public signal void track_added (Track track);
        public signal void track_removed (Track track);
        public signal void cover_changed ();

        public string title { get; set; }
        protected int _ID = 0;
        protected GLib.List<Track> _tracks;
        protected bool is_cover_loading = false;

        public string cover_path { get; protected set; }

        Gdk.Pixbuf? _cover = null;
        public Gdk.Pixbuf? cover {
            get {
                return _cover;
            } protected set {
                _cover = value;
                is_cover_loading = false;
                cover_changed ();
            }
        }

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            _tracks = new GLib.List<Track> ();
        }

        public Track? get_track_by_path (string path) {
            Track? return_value = null;
            lock (_tracks) {
                foreach (var track in _tracks) {
                    if (track.path == path) {
                        return_value = track;
                        break;
                    }
                }
                return return_value;
            }
        }

        public Track? get_next_track (Track current) {
            int i = _tracks.index (current) + 1;
            if (i < _tracks.length ()) {
                return _tracks.nth_data (i);
            }
            return null;
        }

        public Track? get_prev_track (Track current) {
            int i = _tracks.index (current) - 1;
            if (i > - 1) {
                return _tracks.nth_data (i);
            }
            return null;
        }

        public Track? get_first_track () {
            return _tracks.nth_data (0);
        }

        public void remove_track (Track track) {
            this._tracks.remove (track);
            track_removed (track);
        }

        protected void add_track (Track track) {
            lock (_tracks) {
                this._tracks.append (track);
                _tracks.sort_with_data ((a, b) => {
                    if (a.disc != b.disc) {
                        return a.disc - b.disc;
                    }
                    if (a.track != b.track) {
                        return a.track - b.track;
                    }
                    return a.title.collate (b.title);
                });
            }
            track_added (track);
        }

        public void set_new_cover (Gdk.Pixbuf cover) {
            this.cover = save_cover (cover);
        }

        protected Gdk.Pixbuf? save_cover (Gdk.Pixbuf p) {
            Gdk.Pixbuf? pixbuf = library_manager.align_and_scale_pixbuf (p, 256);
            try {
                pixbuf.save (cover_path, "jpeg", "quality", "100");
            } catch (Error err) {
                warning (err.message);
            }
            return pixbuf;
        }
    }
}
