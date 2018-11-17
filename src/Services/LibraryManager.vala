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

        public signal void sync_started ();
        public signal void sync_finished ();
        public signal void added_new_artist (Objects.Artist artist);
        public signal void added_new_album (Objects.Album album);
        public signal void added_new_playlist (Objects.Playlist playlist);
        public signal void added_new_track (Objects.Track track);
        public signal void artist_removed (Objects.Artist artist);
        public signal void removed_playlist (Objects.Playlist playlist);
        public signal void added_new_radio (Objects.Radio radio);
        public signal void removed_radio (Objects.Radio radio);
        public signal void player_state_changed (Gst.State state);
        public signal void audio_cd_connected (Objects.AudioCD ausdio_cd);
        public signal void audio_cd_disconnected (Volume volume);
        public signal void mobile_phone_connected (Objects.MobilePhone mobile_phone);
        public signal void mobile_phone_disconnected (Volume volume);
        public signal void cache_loaded ();

        public Services.TagManager tg_manager { get; construct set; }
        public Services.DataBaseManager db_manager { get; construct set; }
        public Services.LocalFilesManager lf_manager { get; construct set; }
        public Services.Player player { get; construct set; }
        public Services.DeviceManager device_manager { get; construct set; }

        Settings settings;

        uint finish_timer = 0;

        public GLib.List<Objects.Artist> artists {
            get {
                return db_manager.artists;
            }
        }

        public GLib.List<Objects.Radio> radios {
            get {
                return db_manager.radios;
            }
        }

        public GLib.List<Objects.Playlist> playlists {
            get {
                return db_manager.playlists;
            }
        }

        construct {
            settings = Settings.get_default ();

            tg_manager = Services.TagManager.instance;
            tg_manager.discovered_new_item.connect (discovered_new_local_item);
            tg_manager.discover_finished.connect (() => { sync_finished (); });

            db_manager = Services.DataBaseManager.instance;
            db_manager.added_new_artist.connect ((artist) => { added_new_artist (artist); });
            db_manager.added_new_album.connect ((album) => { added_new_album (album); });
            db_manager.added_new_playlist.connect ((playlist) => { added_new_playlist (playlist); });
            db_manager.adden_new_track.connect ((track) => { added_new_track (track); });
            db_manager.artist_removed.connect ((artist) =>  { artist_removed (artist); });
            db_manager.removed_playlist.connect ((playlist) => { removed_playlist (playlist); });
            db_manager.added_new_radio.connect ((radio) => { added_new_radio (radio); });
            db_manager.removed_radio.connect ((radio) => {
                if (player.current_radio == radio) {
                    player.reset_playing ();
                }
                removed_radio (radio);
            });

            lf_manager = Services.LocalFilesManager.instance;
            lf_manager.found_music_file.connect (found_local_music_file);

            player = Services.Player.instance;
            player.state_changed.connect ((state) => { player_state_changed (state); });

            device_manager = Services.DeviceManager.instance;
            device_manager.audio_cd_added.connect ((volume) => {
                var audio_cd = new Objects.AudioCD (volume);
                audio_cd.mb_disc_id_calculated.connect (() => {
                    mb_disc_id_calculated (audio_cd);
                });
                audio_cd_connected (audio_cd);
            });
            device_manager.audio_cd_removed.connect ((volume) => {
                audio_cd_disconnected (volume);
            });
            device_manager.mtp_added.connect ((volume) => {
                var mobile_phone = new Objects.MobilePhone (volume);
                mobile_phone_connected (mobile_phone);
            });
            device_manager.mtp_removed.connect ((volume) => {
                mobile_phone_disconnected (volume);
            });
        }

        private LibraryManager () {
        }

        public Objects.Artist ? get_artist_by_id (int id) {
            foreach (var artist in artists) {
                if (artist.ID == id) {
                    return artist;
                }
            }
            return null;
        }

        public Objects.Album ? get_album_by_id (int id) {
            foreach (var artist in artists) {
                foreach (var album in artist.albums) {
                    if (album.ID == id) {
                        return album;
                    }
                }
            }
            return null;
        }

        // LOCAL FILES REGION
        public async void sync_library_content () {
            new Thread <void*> ("sync_library_content", () => {
                sync_started ();
                remove_non_existent_items ();
                scan_local_library_for_new_files (settings.library_location);
                finish_timeout ();
                return null;
            });
        }

        public void remove_non_existent_items () {
            var artists_copy = artists.copy ();
            foreach (var artist in artists_copy) {
                var tracks = artist.tracks.copy ();
                foreach (var track in tracks) {
                    if (!track.file_exists ()) {
                        db_manager.remove_track (track);
                    }
                }
            }
            var playlists_copy = playlists.copy ();
            foreach (var playlist in playlists_copy) {
                var tracks = playlist.tracks.copy ();
                foreach (var track in tracks) {
                    if (!track.file_exists ()) {
                        db_manager.remove_track (track);
                    }
                }
            }
        }

        public void scan_local_library_for_new_files (string uri) {
            lf_manager.scan (uri);
        }

        public void found_local_music_file (string uri) {
            cancel_finish_timeout ();
            new Thread<void*> ("found_local_music_file", () => {
                if (!db_manager.music_file_exists (uri)) {
                    if (tg_manager.discover_counter == 0) {
                        sync_started ();
                    }
                    tg_manager.add_discover_uri (uri);
                } else if (tg_manager.discover_counter == 0) {
                    finish_timeout ();
                }
                return null;
            });
        }

        private void finish_timeout () {
            lock (finish_timer) {
                cancel_finish_timeout ();

                finish_timer = Timeout.add (1000, () => {
                    sync_finished ();
                    cancel_finish_timeout ();
                    return false;
                });
            }
        }

        private void cancel_finish_timeout () {
            lock (finish_timer) {
                if (finish_timer != 0) {
                    Source.remove (finish_timer);
                    finish_timer = 0;
                }
            }
        }

        // AUDIO CD REGION
        private void mb_disc_id_calculated (Objects.AudioCD audio_cd) {
            MusicBrainzManager.fill_audio_cd (audio_cd);
        }

        // DATABASE REGION
        public void discovered_new_local_item (Objects.Artist artist, Objects.Album album, Objects.Track track) {
            new Thread<void*> ("discovered_new_local_item", () => {
                if (settings.import_into_library && !track.uri.has_prefix (settings.library_location)) {
                    var target_dir = settings.library_location + "/" + artist.name + "/" + album.title;
                    var target_file = target_dir + "/" + Path.get_basename (track.uri);

                    File target_folder = File.new_for_uri (target_dir);
                    if (!target_folder.query_exists ()) {
                        DirUtils.create_with_parents (target_folder.get_path (), 0755);
                    }
                    target_folder.dispose ();

                    File target = File.new_for_uri (target_file);

                    if (!target.query_exists ()) {
                        File source = File.new_for_uri (track.uri);
                        try {
                            source.copy (target, FileCopyFlags.NONE);
                            track.uri = target.get_uri ();
                        } catch (Error err) {
                            warning (err.message);
                        }

                        source.dispose ();
                    } else {
                        return null;
                    }
                    target.dispose ();
                }
                var db_artist = db_manager.insert_artist_if_not_exists (artist);
                var db_album = db_artist.add_album_if_not_exists (album);
                db_album.add_track_if_not_exists (track);
                return null;
            });
        }

        public void reset_library () {
            player.reset_playing ();
            db_manager.reset_database ();
            File directory = File.new_for_path (PlayMyMusicApp.instance.COVER_FOLDER);
            try {
                var children = directory.enumerate_children ("", 0);
                FileInfo file_info;
                while ((file_info = children.next_file ()) != null) {
                    FileUtils.remove (GLib.Path.build_filename (PlayMyMusicApp.instance.COVER_FOLDER, file_info.get_name ()));
                }
                children.close ();
                children.dispose ();
            } catch (Error err) {
                warning (err.message);
            }
            directory.dispose ();
        }

        public void rescan_library () {
            reset_library ();
            scan_local_library_for_new_files (settings.library_location);
        }

        public bool radio_station_exists (string url) {
            return db_manager.radio_station_exists (url);
        }

        public void save_radio_station (Objects.Radio radio) {
            if (radio.ID == 0) {
                db_manager.insert_radio (radio);
            } else {
                db_manager.update_radio (radio);
                radio.reset_stream_file ();
            }
            radio.save_cover ();
        }

        public void remove_radio_station (Objects.Radio radio) {
            db_manager.delete_radio (radio);
        }

        public void add_track_into_playlist (Objects.Playlist playlist, int track_id) {
            if (!playlist.has_track (track_id)) {
                db_manager.insert_track_into_playlist (playlist, track_id);
            }
        }

        public Objects.Playlist create_new_playlist () {
            string new_title = _ ("New Playlist");

            string next_title = new_title;

            var playlist = db_manager.get_playlist_by_title (next_title);
            for (int i = 1; playlist != null; i++) {
                next_title = "%s (%d)".printf (new_title, i);
                playlist = db_manager.get_playlist_by_title (next_title);
            }

            playlist = new Objects.Playlist ();
            playlist.title = next_title;

            db_manager.insert_playlist (playlist);

            return playlist;
        }

        public void remove_playlist (Objects.Playlist playlist) {
            db_manager.remove_playlist (playlist);
        }

        public void remove_track_from_playlist (Objects.Track track) {
            db_manager.remove_track_from_playlist (track);
        }

        public void resort_track_in_playlist (Objects.Playlist playlist, Objects.Track track, int new_sort_value) {
            db_manager.resort_track_in_playlist (playlist, track, new_sort_value);
        }

        public void export_playlist (Objects.Playlist playlist, string? title = null) {
            var file = new Gtk.FileChooserDialog (
                _ ("Choose an image…"), PlayMyMusicApp.instance.mainwindow,
                Gtk.FileChooserAction.SAVE,
                _ ("_Cancel"), Gtk.ResponseType.CANCEL,
                _ ("_Save"), Gtk.ResponseType.ACCEPT);

            var filter = new Gtk.FileFilter ();
            filter.set_filter_name (_ ("Playlist (.m3u)"));
            filter.add_mime_type ("audio/x-mpegurl");

            file.add_filter (filter);

            var file_name = (title != null ? title : playlist.title) + ".m3u";
            file.set_current_name (file_name);

            if (file.run () == Gtk.ResponseType.ACCEPT && file.get_filename () != null) {
                var file_content = "#EXTM3U";
                foreach (var track in playlist.tracks) {
                    file_content += "\n#EXTINF:-1," + track.album.artist.name + " - " + track.title;
                    file_content += "\n" + track.uri;
                }

                try {
                    FileUtils.set_contents (file.get_filename (), file_content);
                } catch (Error err) {
                    warning (err.message);
                }
            }

            file.destroy ();
        }

        public void import_playlist () {
            var filename = choose_playlist ();
            if (filename != null) {
                string content = "";
                try {
                    FileUtils.get_contents (filename, out content);
                } catch (Error err) {
                    warning (err.message);
                }

                if (content != "") {
                    var lines = content.split ("\n");

                    var file_title = Path.get_basename (filename);
                    if (file_title.index_of (".") > -1) {
                        file_title = file_title.substring (0, file_title.last_index_of ("."));
                    }

                    var playlist_title = file_title;
                    for (int i = 2; db_manager.get_playlist_by_title (playlist_title) != null; i++) {
                        playlist_title = ("%s (%d)").printf (file_title, i);
                    }

                    var playlist = new Objects.Playlist ();
                    playlist.title = playlist_title;
                    db_manager.insert_playlist (playlist);

                    foreach (var line in lines) {
                        if (!line.has_prefix ("#")) {
                            var track = db_manager.get_track_by_uri (line);
                            if (track != null) {
                                add_track_into_playlist (playlist, track.ID);
                            }
                        }
                    }
                }
            }
        }

        public async void load_database_cache () {
            new Thread <void*> ("load_database_cache", () => {
                uint dummy_counter = 0;
                foreach (var artist in artists) {
                    foreach (var album in artist.albums) {
                        dummy_counter += album.tracks.length ();
                    }
                }
                cache_loaded ();
                return null;
            });
        }

        //PLAYER REGION
        public void play_track (Objects.Track track, PlayMode play_mode) {
            player.set_track (track, play_mode);
        }

        public void play_radio (Objects.Radio radio) {
            player.set_radio (radio);
        }

        //PIXBUF
        public string? choose_new_cover () {
            string? return_value = null;
            var chooser = new Gtk.FileChooserDialog (
                _ ("Choose an image…"), PlayMyMusicApp.instance.mainwindow,
                Gtk.FileChooserAction.OPEN,
                _ ("_Cancel"), Gtk.ResponseType.CANCEL,
                _ ("_Open"), Gtk.ResponseType.ACCEPT);

            var filter = new Gtk.FileFilter ();
            filter.set_filter_name (_ ("Images"));
            filter.add_mime_type ("image/*");

            chooser.add_filter (filter);

            Gtk.Image preview_area = new Gtk.Image ();
            chooser.set_preview_widget (preview_area);
            chooser.set_use_preview_label (false);
            chooser.set_select_multiple (false);

            chooser.update_preview.connect (() => {
                string filename = chooser.get_preview_filename ();
                if (filename != null) {
                    try {
            	        Gdk.Pixbuf pixbuf = new Gdk.Pixbuf.from_file_at_scale (filename, 150, 150, true);
            	        preview_area.set_from_pixbuf (pixbuf);
            	        preview_area.show ();
                    } catch (Error e) {
            	        preview_area.hide ();
                    }
                } else {
                    preview_area.hide ();
                }
            });

            if (chooser.run () == Gtk.ResponseType.ACCEPT) {
                return_value = chooser.get_filename ();
            }

            chooser.destroy ();
            return return_value;
        }

        public string? choose_playlist () {
            string? return_value = null;
            var chooser = new Gtk.FileChooserDialog (
                _ ("Choose a playlist…"), PlayMyMusicApp.instance.mainwindow,
                Gtk.FileChooserAction.OPEN,
                _ ("_Cancel"), Gtk.ResponseType.CANCEL,
                _ ("_Open"), Gtk.ResponseType.ACCEPT);

            var filter = new Gtk.FileFilter ();
            filter.set_filter_name (_ ("Playlist (.m3u)"));
            filter.add_mime_type ("audio/x-mpegurl");

            chooser.add_filter (filter);

            if (chooser.run () == Gtk.ResponseType.ACCEPT) {
                return_value = chooser.get_filename ();
            }

            chooser.destroy ();
            return return_value;
        }

        public string? choose_folder () {
            string? return_value = null;
            Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
                _ ("Select a folder."), PlayMyMusicApp.instance.mainwindow, Gtk.FileChooserAction.SELECT_FOLDER,
                _ ("_Cancel"), Gtk.ResponseType.CANCEL,
                _ ("_Open"), Gtk.ResponseType.ACCEPT);

            var filter = new Gtk.FileFilter ();
            filter.set_filter_name (_ ("Folder"));
            filter.add_mime_type ("inode/directory");

            chooser.add_filter (filter);

            if (chooser.run () == Gtk.ResponseType.ACCEPT) {
                return_value = chooser.get_file ().get_uri ();
            }

            chooser.destroy ();
            return return_value;
        }

        public Gdk.Pixbuf ? align_and_scale_pixbuf (Gdk.Pixbuf p, int size) {
            Gdk.Pixbuf ? pixbuf = p;
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
