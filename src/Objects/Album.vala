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
    public class Album : GLib.Object {
        public signal void cover_changed ();
        public signal void track_added (Track track);
        public signal void track_removed (Track track);

        bool is_cover_loading = false;

        Artist _artist;
        public Artist artist {
            get {
                return _artist;
            }
        }

        int _ID = 0;
        public int ID {
            get {
                return _ID;
            } set {
                _ID = value;
                load_cover_async.begin ();
            }
        }
        public string title { get; set; }
        public int year { get; set; }
        Gdk.Pixbuf? _cover = null;
        public Gdk.Pixbuf? cover {
            get {
                return _cover;
            } private set {
                _cover = value;
                is_cover_loading = false;
                cover_changed ();
            }
        }

        GLib.List<Track> _tracks;
        public GLib.List<Track> tracks {
            get {
                if (_tracks == null) {
                    _tracks = PlayMyMusic.Services.LibraryManager.instance.db_manager.get_track_collection (this);
                }
                return _tracks;
            }
        }

        construct {
            _tracks = new GLib.List<Track> ();
            year = -1;
        }

        public Album (Artist artist) {
            this.set_artist (artist);
        }

        public void set_artist (Artist artist) {
            this._artist = artist;
        }

        public void add_track (Track track) {
            track.set_album (this);
            this._tracks.append (track);
            load_cover_async.begin ();
            track_added (track);
        }

        public void remove_track (Track track) {
            this._tracks.remove (track);
            track_added (track);
        }

        public Track? get_next_track (Track current) {
            _tracks.sort_with_data ((a, b) => {
                if (a.track > 0 && b.track > 0){
                    return a.track - b.track;
                }
                return a.title.collate (b.title);
            });

            int i = tracks.index (current) + 1;
            if (i < tracks.length ()) {
                return tracks.nth_data (i);
            }
            return null;
        }

         public Track? get_prev_track (Track current) {
            _tracks.sort_with_data ((a, b) => {
                if (a.track > 0 && b.track > 0){
                    return a.track - b.track;
                }
                return a.title.collate (b.title);
            });

            int i = tracks.index (current) - 1;
            if (i > - 1) {
                return tracks.nth_data (i);
            }
            return null;
        }

        public Track? get_track_by_path (string path) {
            Track? return_value = null;
            lock (_tracks) {
                foreach (var track in tracks) {
                    if (track.path == path) {
                        return_value = track;
                        break;
                    }
                }
            }
            return return_value;
        }

// COVER REGION

        private async void load_cover_async () {
            if (is_cover_loading || cover != null || this.ID == 0) {
                return;
            }
            load_or_create_cover.begin ((obj, res) => {
                Gdk.Pixbuf? return_value = load_or_create_cover.end (res);
                if (return_value != null) {
                    this.cover = return_value;
                }
            });
        }

        private async Gdk.Pixbuf? load_or_create_cover () {
            is_cover_loading = true;
            SourceFunc callback = load_or_create_cover.callback;

            Gdk.Pixbuf? return_value = null;
            new Thread<void*> (null, () => {
                var cover_cache_path = GLib.Path.build_filename (PlayMyMusic.PlayMyMusicApp.instance.COVER_FOLDER, ("album_%d.jpg").printf(this.ID));

                var cover_full_path = File.new_for_path (cover_cache_path);
                if (cover_full_path.query_exists ()) {
                    try {
                        return_value = new Gdk.Pixbuf.from_file (cover_cache_path);
                        Idle.add ((owned) callback);
                        return null;
                    } catch (Error err) {
                        warning (err.message);
                    }
                }

    string[] cover_files = {"cover.jpg", "Cover.jpg", "album.jpg", "Album.jpg", "folder.jpg", "Folder.jpg", "front.jpg", "Front.jpg"};

                foreach (var track in tracks) {
                    var dir_name = GLib.Path.get_dirname (track.path);
                    foreach (var cover_file in cover_files) {
                        var cover_path = GLib.Path.build_filename (dir_name, cover_file);
                        cover_full_path = File.new_for_path (cover_path);
                        if (cover_full_path.query_exists ()) {
                            try {
                                return_value = align_and_cache_pixbuf (new Gdk.Pixbuf.from_file (cover_path), cover_cache_path);
                                Idle.add ((owned) callback);
                                return null;
                            } catch (Error err) {
                                warning (err.message);
                            }
                        }
                    }
                }
                Gst.PbUtils.Discoverer discoverer;
                try {
                    discoverer = new Gst.PbUtils.Discoverer ((Gst.ClockTime) (5 * Gst.SECOND));
                } catch (Error err) {
                    warning (err.message);
                    Idle.add ((owned) callback);
                    return null;
                }
                foreach (var track in tracks) {
                    var file = File.new_for_path (track.path);
                    Gst.PbUtils.DiscovererInfo info;
                    try {
                        info = discoverer.discover_uri (file.get_uri ());
                    } catch (Error err) {
                        warning (err.message);
                        Idle.add ((owned) callback);
                        return null;
                    }
                    if (info.get_result () != Gst.PbUtils.DiscovererResult.OK) {
                        continue;
                    }
                    
                    Gdk.Pixbuf pixbuf = null;
                    var tag_list = info.get_tags ();
                    var sample = get_cover_sample (tag_list);

                    if (sample == null) {
                        tag_list.get_sample_index (Gst.Tags.PREVIEW_IMAGE, 0, out sample);
                    }

                    if (sample != null) {
                        var buffer = sample.get_buffer ();

                        if (buffer != null) {
                            pixbuf = get_pixbuf_from_buffer (buffer);
                            if (pixbuf != null) {
                                discoverer.stop ();
                                return_value = align_and_cache_pixbuf (pixbuf, cover_cache_path);
                                Idle.add ((owned) callback);
                                return null;
                            }
                        }
                    }
                }

                Idle.add ((owned) callback);
                return null;
            });
            yield;
            is_cover_loading = false;
            return return_value;
        }

        private Gdk.Pixbuf? align_and_cache_pixbuf (Gdk.Pixbuf? p, string cover_cache_path) {
            Gdk.Pixbuf? pixbuf = p;
            if (pixbuf.width != pixbuf.height) {
                if (pixbuf.width > pixbuf.height) {
                    int dif = pixbuf.width - pixbuf.height;
                    pixbuf = new Gdk.Pixbuf.subpixbuf (pixbuf, dif, 0, pixbuf.height, pixbuf.height);
                } else {
                    int dif = pixbuf.height - pixbuf.width;
                    pixbuf = new Gdk.Pixbuf.subpixbuf (pixbuf, 0, dif, pixbuf.width, pixbuf.width);
                }
            }
            pixbuf = pixbuf.scale_simple (256, 256, Gdk.InterpType.BILINEAR);
            try {
                pixbuf.save (cover_cache_path, "jpeg");
            } catch (Error err) {
                warning (err.message);
            }
            return pixbuf;
        }

        private static Gst.Sample? get_cover_sample (Gst.TagList tag_list) {
            Gst.Sample cover_sample = null;
            Gst.Sample sample;
            for (int i = 0; tag_list.get_sample_index (Gst.Tags.IMAGE, i, out sample); i++) {
                var caps = sample.get_caps ();
                unowned Gst.Structure caps_struct = caps.get_structure (0);
                int image_type = Gst.Tag.ImageType.UNDEFINED;
                caps_struct.get_enum ("image-type", typeof (Gst.Tag.ImageType), out image_type);
                if (image_type == Gst.Tag.ImageType.UNDEFINED && cover_sample == null) {
                    cover_sample = sample;
                } else if (image_type == Gst.Tag.ImageType.FRONT_COVER) {
                    return sample;
                }
            }

            return cover_sample;
        }

        private static Gdk.Pixbuf? get_pixbuf_from_buffer (Gst.Buffer buffer) {
            Gst.MapInfo map_info;

            if (!buffer.map (out map_info, Gst.MapFlags.READ)) {
                warning ("Could not map memory buffer");
                return null;
            }

            Gdk.Pixbuf pix = null;

            try {
                var loader = new Gdk.PixbufLoader ();
                if (loader.write (map_info.data) && loader.close ()) {
                    pix = loader.get_pixbuf ();
                }
            } catch (Error err) {
                warning ("Error processing image data: %s", err.message);
            }

            buffer.unmap (map_info);

            return pix;
        }
    }
}
