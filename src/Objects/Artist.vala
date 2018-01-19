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
        public signal void album_removed (Album album);

        public new int ID {
            get {
                return _ID;
            } set {
                _ID = value;
                if (value > 0) {
                    this.cover_path = GLib.Path.build_filename (PlayMyMusicApp.instance.COVER_FOLDER, ("artist_%d.jpg").printf (this.ID));
                    this.background_path = GLib.Path.build_filename (PlayMyMusicApp.instance.COVER_FOLDER, ("artist_%d_background.png").printf (this.ID));
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

        GLib.List<string> _albums_title;
        public GLib.List<string> albums_title {
            get {
                _albums_title = new GLib.List<string> ();
                lock (_albums) {
                    foreach (var album in albums) {
                        _albums_title.append (album.title);
                    }
                }
                return _albums_title;
            }
        }

        public new GLib.List<Track> tracks {
            get {
                return _tracks;
            }
        }

        construct {
            cover_changed.connect (() => {
                create_background ();
            });

            track_added.connect (() => {
                load_cover_async.begin ();
            });
            album_removed.connect ((album) => {
                _albums.remove (album);
                if (albums.length () == 0) {
                    db_manager.remove_artist (this);
                }
            });
            removed.connect (() => {
                db_manager.artist_removed (this);
            });
            updated.connect (() => {
                if (settings.save_id3_tags) {
                    foreach (var album in albums) {
                        foreach (var track in album.tracks) {
                            track.save_id3_tags ();
                        }
                    }
                }
            });
        }

        public void clear_albums () {
            _albums = new GLib.List<Album> ();
        }

        public Album? get_album_by_title (string title) {
            Album? return_value = null;
            lock (_albums) {
                foreach (var album in albums) {
                    if (album.title == title) {
                        return_value = album;
                        break;
                    }
                }
            }
            return return_value;
        }

        public void add_album (Album album) {
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
                return_value = get_album_by_title (new_album.title);
                if (return_value == null) {
                    new_album.set_artist (this);
                    add_album (new_album);
                    db_manager.insert_album (new_album);
                    return_value = new_album;
                }
                return return_value;
            }
        }

        public void merge (GLib.List<Objects.Artist> artists) {
            foreach (var artist in artists) {
                if (artist.ID == ID) {
                    continue;
                }

                var albums_copy = artist.albums.copy ();
                foreach (var album in albums_copy) {
                    var album_exists = this.get_album_by_title (album.title);
                    if (album_exists == null) {
                        album.set_artist (this);
                        db_manager.update_album (album);
                        this.add_album (album);
                        library_manager.added_new_album (album);
                    } else {
                        GLib.List<Objects.Album> albums = new GLib.List<Objects.Album> ();
                        albums.append (album);
                        album_exists.merge (albums);
                    }
                }
                foreach (var album in artist.albums) {
                    album.removed ();
                }
                db_manager.remove_artist (artist);
            }
        }

        // COVER
        public void set_custom_cover_file (string uri) {
            var first_track = this.tracks.first ().data;
            if (first_track != null) {
                var destination = File.new_for_uri (GLib.Path.get_dirname(GLib.Path.get_dirname (first_track.uri)) + "/artist.jpg");
                var source = File.new_for_path (uri);
                try {
                    source.copy (destination, GLib.FileCopyFlags.OVERWRITE);
                } catch (Error err) {
                    warning (err.message);
                }
                destination.dispose ();
                source.dispose ();
            }
        }

        public async void load_cover_async () {
            if (is_cover_loading || cover != null || this.ID == 0) {
                return;
            }
            is_cover_loading = true;
            load_or_create_cover.begin ((obj, res) => {
                Gdk.Pixbuf? return_value = load_or_create_cover.end (res);
                if (return_value != null) {
                    this.cover = return_value;
                } else if (settings.load_artist_from_musicbrainz && !this.name.down ().contains ("various") && !this.name.down ().contains ("artist")) {
                    Services.MusicBrainzManager.instance.fill_artist_cover_queue (this);
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
                        cover_full_path.dispose ();
                        return null;
                    } catch (Error err) {
                        warning (err.message);
                    }
                }

                string[] cover_files = PlayMyMusic.Settings.get_default ().artists;
                foreach (var track in tracks) {
                    var dir_name = GLib.Path.get_dirname (track.uri);
                    foreach (var cover_file in cover_files) {
                        var cover_uri = dir_name + "/" + cover_file;
                        cover_full_path = File.new_for_uri (cover_uri);
                        if (cover_full_path.query_exists ()) {
                            try {
                                return_value = save_cover (new Gdk.Pixbuf.from_file (cover_full_path.get_path ()), 256);
                                Idle.add ((owned) callback);
                                cover_full_path.dispose ();
                                return null;
                            } catch (Error err) {
                                warning (err.message);
                            }
                        }
                        // SUB FOLDER IF LOCATION LIKE: Artist/Album
                        var sub_dir_name = GLib.Path.get_dirname (dir_name);
                        cover_uri = sub_dir_name + "/" + cover_file;
                        cover_full_path = File.new_for_uri (cover_uri);
                        if (cover_full_path.query_exists ()) {
                            try {
                                return_value = save_cover (new Gdk.Pixbuf.from_file (cover_full_path.get_path ()), 256);
                                Idle.add ((owned) callback);
                                cover_full_path.dispose ();
                                return null;
                            } catch (Error err) {
                                warning (err.message);
                            }
                        }

                        // SUB SUB FOLDER IF LOCATION LIKE: Artist/Album/CD1
                        sub_dir_name = GLib.Path.get_dirname (sub_dir_name);
                        cover_uri = sub_dir_name + "/" + cover_file;
                        cover_full_path = File.new_for_uri (cover_uri);
                        if (cover_full_path.query_exists ()) {
                            try {
                                return_value = save_cover (new Gdk.Pixbuf.from_file (cover_full_path.get_path ()), 256);
                                Idle.add ((owned) callback);
                                cover_full_path.dispose ();
                                return null;
                            } catch (Error err) {
                                warning (err.message);
                            }
                        }
                    }
                }
                Idle.add ((owned) callback);
                cover_full_path.dispose ();
                return null;
            });
            yield;
            return return_value;
        }
    }
}
