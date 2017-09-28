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
    public class Radio: GLib.Object {
        PlayMyMusic.Services.LibraryManager library_manager;
        public signal void cover_changed ();
        public signal void removed ();

        int _ID = 0;
        public int ID {
            get {
                return _ID;
            } set {
                _ID = value;
                if (cover != null) {
                    save_cover (cover);
                } else {
                    load_cover ();
                }
            }
        }
        public string title { get; set; }
        public string url { get; set; }

        string? _file = null;
        public string? file {
            get {
                if (_file == null) {
                    _file = get_stream_file ();
                }

                return _file;
            }
        }

        Gdk.Pixbuf? _cover = null;
        public Gdk.Pixbuf? cover {
            get {
                return _cover;
            } private set {
                _cover = value;
                cover_changed ();
            }
        }

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            removed.connect (() => {
                var cover_cache_path = GLib.Path.build_filename (PlayMyMusic.PlayMyMusicApp.instance.COVER_FOLDER, ("radio_%d.jpg").printf(this.ID));
                var file = File.new_for_path (cover_cache_path);
                if (file.query_exists ()) {
                    file.delete_async.begin ();
                }
            });
        }

        public Radio () {}

        public Radio.with_parameters (string title, string url, Gdk.Pixbuf? cover = null) {
            this.title = title;
            this.url = url;
            this.cover = cover;
        }

        private string? get_stream_file () {
            string? return_value = null;

            string? content = get_stream_content ();
            if (content != null) {
                return_value = get_file_from_m3u (content);
                if (return_value == null) {
                    return_value = get_file_from_pls (content);
                }
            } else {
                return_value = this.url;
            }

            return return_value;
        }

        private string? get_stream_content () {
            string? return_value = null;
            var session = new Soup.Session();
            var msg = new Soup.Message ("GET", this.url);
            var loop = new MainLoop();

            session.send_async.begin (msg, null, (obj, res) => {
                var content_type = msg.response_headers.get_one ("Content-Type");
                if (content_type != "audio/mpeg") {
                    session.send_message (msg);
                    var data = (string) msg.response_body.data;
                    if (msg.status_code == 200) {
                        return_value = data;
                    }
                }
                loop.quit ();
            });

            loop.run ();
            return return_value;
        }

        private string? get_file_from_m3u (string content) {
            string[] lines = content.split ("\n");
            foreach (unowned string line in lines) {
                if (line.has_prefix ("http") && line.index_of ("#") == -1) {
                    return line;
                }
            }
            return null;
        }

        private string? get_file_from_pls (string content) {
            string group = "playlist";

            var file = new KeyFile ();
            try {
                file.load_from_data (content, -1, KeyFileFlags.NONE);
            } catch (Error err) {
                warning (err.message);
            }

            if (!file.has_group (group)) {
                return null;
            }

            try {
                foreach (unowned string key in file.get_keys (group)) {
                    string val = file.get_value (group, key);
                        if (key.down ().has_prefix ("file")) {
                        return val;
                    }
                }
            } catch (Error err) {
                warning (err.message);
            }

            return null;
        }

        public void set_new_cover (Gdk.Pixbuf cover) {
            save_cover (cover);
        }

        private Gdk.Pixbuf? save_cover (Gdk.Pixbuf p) {
            var cover_cache_path = GLib.Path.build_filename (PlayMyMusic.PlayMyMusicApp.instance.COVER_FOLDER, ("radio_%d.jpg").printf(this.ID));
            Gdk.Pixbuf? pixbuf = library_manager.align_and_scale_pixbuf (p, 48);
            try {
                pixbuf.save (cover_cache_path, "jpeg", "quality", "100");
            } catch (Error err) {
                warning (err.message);
            }
            return pixbuf;
        }

        private void load_cover () {
            var cover_cache_path = GLib.Path.build_filename (PlayMyMusic.PlayMyMusicApp.instance.COVER_FOLDER, ("radio_%d.jpg").printf(this.ID));
            var file = File.new_for_path (cover_cache_path);
            if (file.query_exists ()) {
                try {
                    this.cover = new Gdk.Pixbuf.from_file (cover_cache_path);
                } catch (Error err) {
                    warning (err.message);
                }
            }
        }
    }
}
