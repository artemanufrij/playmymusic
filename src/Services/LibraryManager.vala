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
    public class LibraryManager : GLib.Object {
        static LibraryManager _instance = null;
        public static LibraryManager instance {
            get {
                if (_instance == null) {
                    _instance = new LibraryManager ();
                }
                return _instance;
            }
        }

        public signal void tag_discover_started ();
        public signal void tag_discover_finished ();
        public signal void added_new_artist (PlayMyMusic.Objects.Artist artist);
        public signal void added_new_album (PlayMyMusic.Objects.Album album);
        public signal void added_new_radio (PlayMyMusic.Objects.Radio radio);
        public signal void removed_radio (PlayMyMusic.Objects.Radio radio);
        public signal void player_state_changed (Gst.State state);

        public PlayMyMusic.Services.TagManager tg_manager { get; construct set; }
        public PlayMyMusic.Services.DataBaseManager db_manager { get; construct set; }
        public PlayMyMusic.Services.LocalFilesManager lf_manager { get; construct set; }
        public PlayMyMusic.Services.Player player { get; construct set; }

        PlayMyMusic.Settings settings;

        public GLib.List<PlayMyMusic.Objects.Artist> artists {
            get {
                return db_manager.artists;
            }
        }

        public GLib.List<PlayMyMusic.Objects.Radio> radios {
            get {
                return db_manager.radios;
            }
        }

        construct {
            settings = PlayMyMusic.Settings.get_default ();

            tg_manager = PlayMyMusic.Services.TagManager.instance;
            tg_manager.discovered_new_item.connect (discovered_new_local_item);
            tg_manager.discover_started.connect ( () => { tag_discover_started (); });
            tg_manager.discover_finished.connect ( () => { tag_discover_finished (); });

            db_manager = PlayMyMusic.Services.DataBaseManager.instance;
            db_manager.added_new_artist.connect ( (artist) => { added_new_artist (artist); });
            db_manager.added_new_album.connect ( (album) => { added_new_album (album); });
            db_manager.added_new_radio.connect ( (radio) => { added_new_radio (radio); });
            db_manager.removed_radio.connect ( (radio) => {
                if (player.current_radio == radio) {
                    player.reset_playing ();
                }
                removed_radio (radio);
            });

            lf_manager = PlayMyMusic.Services.LocalFilesManager.instance;
            lf_manager.found_music_file.connect (found_local_music_file);

            player = PlayMyMusic.Services.Player.instance;
            player.state_changed.connect ((state) => { player_state_changed (state); });
        }

        private LibraryManager () { }

        // LOCAL FILES REGION
        public void scan_local_library (string path) {
            lf_manager.scan (path);
        }

        private void found_local_music_file (string path) {
            new Thread<void*> (null, () => {
                if (!db_manager.music_file_exists (path)) {
                    tg_manager.add_discover_path (path);
                }
                return null;
            });
        }

        // DATABASE REGION
        public void discovered_new_local_item (PlayMyMusic.Objects.Artist artist) {
            var album = artist.albums.first ().data;
            var track = album.tracks.first ().data;

            var db_artist = db_manager.get_artist_by_name (artist.name);
            if (db_artist == null) {
                db_manager.insert_artist (artist);
                db_manager.insert_album (album);
                db_manager.insert_track (track);
            } else {
                var album_db = db_artist.get_album_by_title (album.title);
                if (album_db == null) {
                    artist.remove_album (album);
                    db_artist.add_album (album);
                    db_manager.insert_album (album);
                    db_manager.insert_track (track);
                } else {
                    var track_db = album_db.get_track_by_path (track.path);
                    if (track_db == null) {
                        album.remove_track (track);
                        album_db.add_track (track);
                        db_manager.insert_track (track);
                    }
                }
            }
        }

        public void rescan_library () {
            player.reset_playing ();
            db_manager.reset_database ();
            File directory = File.new_for_path (PlayMyMusic.PlayMyMusicApp.instance.COVER_FOLDER);
            try {
                var children = directory.enumerate_children (FileAttribute.STANDARD_CONTENT_TYPE + "," + FileAttribute.STANDARD_IS_HIDDEN, 0);
                FileInfo file_info;
                while ((file_info = children.next_file ()) != null) {
                     var file = File.new_for_path (GLib.Path.build_filename (PlayMyMusic.PlayMyMusicApp.instance.COVER_FOLDER, file_info.get_name ()));
                     file.@delete ();
                }
            } catch (Error err) {
                warning (err.message);
            }
            scan_local_library (settings.library_location);
        }

        public bool radio_station_exists (string url) {
            return db_manager.radio_station_exists (url);
        }

        public void save_radio_station (PlayMyMusic.Objects.Radio radio) {
            if (radio.ID == 0) {
                db_manager.insert_radio (radio);
            } else {
                db_manager.update_radio (radio);
                radio.reset_stream_file ();
            }
            radio.save_cover ();
        }

        public void remove_radio_station (PlayMyMusic.Objects.Radio radio) {
            db_manager.delete_radio (radio);
        }

        //PLAYER REGION
        public void play_track (PlayMyMusic.Objects.Track track, PlayMode play_mode) {
            player.set_track (track, play_mode);
        }

        public void play_radio (PlayMyMusic.Objects.Radio radio) {
            player.set_radio (radio);
        }

        //PIXBUF

        public string? choose_new_cover () {
            string? return_value = null;
            var cover = new Gtk.FileChooserDialog (
                _("Choose an image…"), PlayMyMusicApp.instance.mainwindow,
                Gtk.FileChooserAction.OPEN,
                _("_Cancel"), Gtk.ResponseType.CANCEL,
                _("_Open"), Gtk.ResponseType.ACCEPT);

            var filter = new Gtk.FileFilter ();
            filter.set_filter_name (_("Images"));
            filter.add_mime_type ("image/*");

            cover.add_filter (filter);

            if (cover.run () == Gtk.ResponseType.ACCEPT) {
                return_value = cover.get_filename ();
            }

            cover.destroy();
            return return_value;
        }

        public string? choose_folder () {
            string? return_value = null;
            Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
                _("Select a folder."), PlayMyMusicApp.instance.mainwindow, Gtk.FileChooserAction.SELECT_FOLDER,
                _("_Cancel"), Gtk.ResponseType.CANCEL,
                _("_Open"), Gtk.ResponseType.ACCEPT);

            var filter = new Gtk.FileFilter ();
            filter.set_filter_name (_("Folder"));
            filter.add_mime_type ("inode/directory");

            chooser.add_filter (filter);

            if (chooser.run () == Gtk.ResponseType.ACCEPT) {
                return_value = chooser.get_file ().get_path ();
            }

            chooser.destroy ();
            return return_value;
        }

        public Gdk.Pixbuf? align_and_scale_pixbuf (Gdk.Pixbuf p, int size) {
            Gdk.Pixbuf? pixbuf = p;
            if (pixbuf.width != pixbuf.height) {
                if (pixbuf.width > pixbuf.height) {
                    int dif = (pixbuf.width - pixbuf.height) / 2;
                    pixbuf = new Gdk.Pixbuf.subpixbuf (pixbuf, dif, 0, pixbuf.height, pixbuf.height);
                } else {
                    int dif = (pixbuf.height - pixbuf.width) / 2;
                    pixbuf = new Gdk.Pixbuf.subpixbuf (pixbuf, 0, dif, pixbuf.width, pixbuf.width);
                }
            }
            pixbuf = pixbuf.scale_simple (size, size, Gdk.InterpType.BILINEAR);
            return pixbuf;
        }
    }
}
