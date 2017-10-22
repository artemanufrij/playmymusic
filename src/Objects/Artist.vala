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
    public class Artist : TracksContainer {
        public new int ID {
            get {
                return _ID;
            } set {
                _ID = value;
                if (value > 0) {
                    this.cover_path = GLib.Path.build_filename (PlayMyMusic.PlayMyMusicApp.instance.COVER_FOLDER, ("artist_%d.jpg").printf (this.ID));
                    this.background_path = GLib.Path.build_filename (PlayMyMusic.PlayMyMusicApp.instance.COVER_FOLDER, ("artist_%d_background.png").printf (this.ID));
                }
            }
        }

        GLib.List<Album> _albums;
        public GLib.List<Album> albums {
            get {
                if (_albums == null) {
                    _albums = new GLib.List<Album> ();
                    foreach (var album in db_manager.get_album_collection (this)) {
                        add_album (album);
                    }
                }
                return _albums;
            }
        }

        public new GLib.List<Track> tracks {
            get {
                return _tracks;
            }
        }

        construct {
            this.cover_changed.connect (() => {
                create_background ();
            });

            this.track_added.connect (() => {
                load_cover_async.begin ();
            });
        }

        public void clear_albums () {
            _albums = new GLib.List<Album> ();
        }

        private void add_album (Album album) {
            this._albums.append (album);
            if (album.artist_track_added_signal_id == 0) {
               album.artist_track_added_signal_id = album.track_added.connect (add_track);
               foreach (var track in album.tracks) {
                    add_track (track);
               }
            }
        }

        public Album add_album_if_not_exists (Album new_album) {
            Album? return_value = null;
            lock (_albums) {
                foreach (var album in albums) {
                    if (album.title == new_album.title) {
                        return_value = album;
                        break;
                    }
                }
                if (return_value == null) {
                    new_album.set_artist (this);
                    add_album (new_album);
                    db_manager.insert_album (new_album);
                    return_value = new_album;
                }
                return return_value;
            }
        }

        private async void load_cover_async () {
            if (is_cover_loading || cover != null || this.ID == 0) {
                return;
            }
            is_cover_loading = true;
            load_or_create_cover.begin ((obj, res) => {
                Gdk.Pixbuf? return_value = load_or_create_cover.end (res);
                if (return_value != null) {
                    this.cover = return_value;
                }
                is_cover_loading = false;
            });
        }

        private async Gdk.Pixbuf? load_or_create_cover () {
            SourceFunc callback = load_or_create_cover.callback;

            Gdk.Pixbuf? return_value = null;
            new Thread<void*> (null, () => {
                var cover_full_path = File.new_for_path (cover_path);
                if (cover_full_path.query_exists ()) {
                    try {
                        return_value = new Gdk.Pixbuf.from_file (cover_path);
                        Idle.add ((owned) callback);
                        return null;
                    } catch (Error err) {
                        warning (err.message);
                    }
                }

                string[] cover_files = PlayMyMusic.Settings.get_default ().artists;
                foreach (var track in tracks) {
                    var dir_name = GLib.Path.get_dirname (track.path);
                    foreach (var cover_file in cover_files) {
                        var cover_path = GLib.Path.build_filename (dir_name, cover_file);
                        cover_full_path = File.new_for_path (cover_path);
                        if (cover_full_path.query_exists ()) {
                            try {
                                return_value = save_cover (new Gdk.Pixbuf.from_file (cover_path), 256);
                                Idle.add ((owned) callback);
                                return null;
                            } catch (Error err) {
                                warning (err.message);
                            }
                        }
                        // SUB FOLDER IF LOCATION LIKE: Artist/Album
                        var sub_dir_name = GLib.Path.get_dirname (dir_name);
                        cover_path = GLib.Path.build_filename (sub_dir_name, cover_file);
                        cover_full_path = File.new_for_path (cover_path);
                        if (cover_full_path.query_exists ()) {
                            try {
                                return_value = save_cover (new Gdk.Pixbuf.from_file (cover_path), 256);
                                Idle.add ((owned) callback);
                                return null;
                            } catch (Error err) {
                                warning (err.message);
                            }
                        }

                        // SUB SUB FOLDER IF LOCATION LIKE: Artist/Album/CD1
                        sub_dir_name = GLib.Path.get_dirname (sub_dir_name);
                        cover_path = GLib.Path.build_filename (sub_dir_name, cover_file);
                        cover_full_path = File.new_for_path (cover_path);
                        if (cover_full_path.query_exists ()) {
                            try {
                                return_value = save_cover (new Gdk.Pixbuf.from_file (cover_path), 256);
                                Idle.add ((owned) callback);
                                return null;
                            } catch (Error err) {
                                warning (err.message);
                            }
                        }
                    }
                }
                Idle.add ((owned) callback);
                return null;
            });
            yield;
            return return_value;
        }

        private void create_background () {
            if (this.cover == null || is_background_loading || this.ID == 0) {
                return;
            }
            is_background_loading = true;

            new Thread<void*> (null, () => {
                File f = File.new_for_path (this.background_path);
                if (f.query_exists ()) {
                    is_background_loading = false;
                    return null;
                }

                double target_size = 1000;

                int width = this.cover.get_width();

                var surface = new Granite.Drawing.BufferSurface ((int)target_size, (int)target_size);

                double zoom = target_size / (double) width;

                Gdk.cairo_set_source_pixbuf (surface.context, this.cover, 0, 0);
                surface.context.scale (zoom, zoom);
                surface.context.paint ();

                surface.exponential_blur (3);
                surface.context.paint ();

                surface.surface.write_to_png (this.background_path);
                is_background_loading = false;
                background_changed ();
                return null;
            });
        }
    }
}
