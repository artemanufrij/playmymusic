/*-
 * Copyright (c) 2017-2018 Artem Anufrij <artem.anufrij@live.de>
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
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
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
        protected Services.LibraryManager library_manager;
        protected Services.DataBaseManager db_manager;
        protected Settings settings;

        public signal void track_added (Track track);
        public signal void track_removed (Track track);
        public signal void cover_changed ();
        public signal void background_changed ();
        public signal void background_found ();
        public signal void removed ();
        public signal void updated ();

        public string title { get; set; default = ""; }
        public string name { get; set; default = ""; }
        protected int _ID = 0;
        public int ID {
            get {
                return _ID;
            } set {
                _ID = value;
            }
        }

        public uint64 duration {
            get {
                uint64 return_value = 0;
                foreach (var track in _tracks) {
                    return_value += track.duration;
                }

                return return_value;
            }
        }

        protected GLib.List<Track> _tracks = null;

        public ulong artist_track_added_signal_id { get; set; default = 0; }

        protected bool is_cover_loading = false;
        protected bool is_background_loading = false;

        public string background_path { get; protected set; default = ""; }
        public string cover_path { get; protected set; default = ""; }

        GLib.List<int> shuffle_index = null;

        public Gdk.Pixbuf ? cover_32 { get; private set; }

        Gdk.Pixbuf ? _cover = null;
        public Gdk.Pixbuf ? cover {
            get {
                return _cover;
            } protected set {
                _cover = value;
                cover_32 = value.scale_simple (32, 32, Gdk.InterpType.BILINEAR);
                cover_changed ();
            }
        }

        Gdk.Pixbuf ? _background = null;
        public Gdk.Pixbuf ? background {
            get {
                if (_background == null && background_path != "") {
                    if (FileUtils.test (background_path, FileTest.EXISTS)) {
                        try {
                            _background = new Gdk.Pixbuf.from_file (background_path);
                        } catch (Error err) {
                            warning (err.message);
                        }
                    }
                }
                return _background;
            } set {
                _background = value;
                background_changed ();
            }
        }

        construct {
            settings = Settings.get_default ();
            library_manager = Services.LibraryManager.instance;
            db_manager = library_manager.db_manager;

            removed.connect (
                () => {
                    FileUtils.remove (cover_path);
                    FileUtils.remove (background_path);
                });
        }

        public Track ? get_track_by_id (int id) {
            Track ? return_value = null;
            lock (_tracks) {
                foreach (var track in _tracks) {
                    if (track.ID == id) {
                        return_value = track;
                        break;
                    }
                }
            }
            return return_value;
        }

        protected bool has_track (Track track) {
            bool return_value = false;
            lock (_tracks) {
                if (_tracks != null) {
                    foreach (var t in _tracks) {
                        if (t.uri == track.uri) {
                            return_value = true;
                            break;
                        }
                    }
                }
            }
            return return_value;
        }

        public Track ? get_next_track (Track current) {
            shuffle_index = null;
            int i = _tracks.index (current) + 1;
            if (i < _tracks.length ()) {
                return _tracks.nth_data (i);
            }
            return null;
        }

        public Track ? get_prev_track (Track current) {
            shuffle_index = null;
            int i = _tracks.index (current) - 1;
            if (i > -1) {
                return _tracks.nth_data (i);
            }
            return null;
        }

        public Track ? get_shuffle_track (Track ? current) {
            if (shuffle_index == null || current == null) {
                shuffle_index = new GLib.List<int> ();
            }

            if (current != null) {
                int i = _tracks.index (current);
                shuffle_index.append (i);
            }

            if (shuffle_index.length () >= _tracks.length ()) {
                shuffle_index = null;
                return null;
            }

            int r = GLib.Random.int_range (0, (int32)_tracks.length ());
            while (shuffle_index.index (r) != -1) {
                r = GLib.Random.int_range (0, (int32)_tracks.length ());
            }

            return _tracks.nth_data (r);
        }

        public Track ? get_first_track () {
            return _tracks.nth_data (0);
        }

        protected void add_track (Track track) {
            if (has_track (track)) {
                return;
            }
            lock (_tracks) {
                if (this is Playlist) {
                    this._tracks.insert_sorted_with_data (
                        track,
                        (a, b) => {
                            return a.track - b.track;
                        });
                } else if (this is AudioCD) {
                    this._tracks.append (track);
                } else {
                    this._tracks.insert_sorted_with_data (track, sort_function);
                }
            }
            track_added (track);
        }

        private int sort_function (Track a, Track b) {
            if (a.album.year != b.album.year) {
                return a.album.year - b.album.year;
            }
            if (a.album.title != b.album.title) {
                return a.album.title.collate (b.album.title);
            }
            if (a.disc != b.disc) {
                return a.disc - b.disc;
            }
            if (a.track != b.track) {
                return a.track - b.track;
            }
            return a.title.collate (b.title);
        }

        public void clear_tracks () {
            _tracks = new GLib.List<Track> ();
        }

        public void set_new_cover (Gdk.Pixbuf cover, int size) {
            FileUtils.remove (background_path);
            this.background = null;
            this.cover = save_cover (cover, size);
        }

        protected Gdk.Pixbuf ? save_cover (Gdk.Pixbuf p, int size) {
            Gdk.Pixbuf ? pixbuf = library_manager.align_and_scale_pixbuf (p, size);
            try {
                pixbuf.save (cover_path, "jpeg", "quality", "100");
            } catch (Error err) {
                warning (err.message);
            }
            return pixbuf;
        }

        public bool has_available_tracks () {
            foreach (var track in _tracks) {
                if (track.file_exists ()) {
                    return true;
                }
            }
            return false;
        }

        public bool has_tracks () {
            return _tracks.length () > 0;
        }

        protected void create_background () {
            if (this.cover == null || is_background_loading || this.ID == 0) {
                return;
            }
            is_background_loading = true;

            new Thread<void*> (
                "create_background",
                () => {
                    if (FileUtils.test (background_path, FileTest.EXISTS)) {
                        is_background_loading = false;
                        background_found ();
                        return null;
                    }

                    double target_size = 1000;

                    int width = this.cover.get_width ();

                    var surface = new Granite.Drawing.BufferSurface ((int)target_size, (int)target_size);

                    double zoom = target_size / (double)width;

                    Gdk.cairo_set_source_pixbuf (surface.context, this.cover, 0, 0);
                    surface.context.scale (zoom, zoom);
                    surface.context.paint ();

                    if (this is AudioCD) {
                        surface.exponential_blur (32);
                    } else {
                        surface.exponential_blur (8);
                    }
                    surface.context.paint ();

                    surface.surface.write_to_png (this.background_path);
                    is_background_loading = false;
                    background_changed ();
                    return null;
                });
        }
    }
}
