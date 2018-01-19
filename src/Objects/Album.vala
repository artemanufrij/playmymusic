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
    public class Album : TracksContainer {
        Artist _artist = null;
        public Artist artist {
            get {
                if (_artist == null) {
                    _artist = db_manager.get_artist_by_album_id (this.ID);
                }
                return _artist;
            }
        }

        public new int ID {
            get {
                return _ID;
            } set {
                _ID = value;
                if (value > 0) {
                    this.cover_path = GLib.Path.build_filename (PlayMyMusic.PlayMyMusicApp.instance.COVER_FOLDER, ("album_%d.jpg").printf (this.ID));
                    load_cover_async.begin ();
                }
            }
        }

        public new GLib.List<Track> tracks {
            get {
                if (_tracks == null) {
                    _tracks = library_manager.db_manager.get_track_collection (this);
                }
                return _tracks;
            }
        }

        public int year { get; set; }

        construct {
            year = -1;
            track_removed.connect ((track) => {
                this._tracks.remove (track);
                if (this.tracks.length () == 0) {
                    db_manager.remove_album (this);
                }
            });
            removed.connect (() => {
                artist.album_removed (this);
            });
            updated.connect (() => {
                if (settings.save_id3_tags) {
                    foreach (var track in tracks) {
                        track.save_id3_tags ();
                    }
                }
            });
        }

        public Album (Artist? artist = null) {
            if (artist != null) {
                this.set_artist (artist);
            }
        }

        public void set_artist (Artist artist) {
            if (artist_track_added_signal_id > 0) {
                disconnect (artist_track_added_signal_id);
                artist_track_added_signal_id = 0;
            }
            this._artist = artist;
        }

        public void add_track_if_not_exists (Track new_track) {
            if (has_track (new_track)) {
                return;
            }
            new_track.set_album (this);
            db_manager.insert_track (new_track);
            add_track (new_track);
            load_cover_async.begin ();
        }

        public void set_custom_cover_file (string uri) {
            var first_track = this.tracks.first ().data;
            if (first_track != null) {
                var destination = File.new_for_uri (GLib.Path.get_dirname (first_track.uri) + "/cover.jpg");
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

        public void merge (GLib.List<Objects.Album> albums) {
            foreach (var album in albums) {
                if (album.ID == ID) {
                    continue;
                }
                foreach (var track in album.tracks) {
                    add_track_if_not_exists (track);
                    db_manager.update_track (track);
                }
                db_manager.remove_album (album);
            }
        }

// COVER REGION
        private async void load_cover_async () {
            if (is_cover_loading || cover != null || this.ID == 0 || this.tracks.length () == 0) {
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
                        cover_full_path.dispose ();
                        Idle.add ((owned) callback);
                        return null;
                    } catch (Error err) {
                        warning (err.message);
                    }
                }

                string[] cover_files = PlayMyMusic.Settings.get_default ().covers;

                foreach (var track in tracks) {
                    var dir_name = GLib.Path.get_dirname (track.uri);
                    foreach (var cover_file in cover_files) {
                        var cover_path = dir_name + "/" + cover_file;
                        cover_full_path = File.new_for_uri (cover_path);
                        if (cover_full_path.query_exists ()) {
                            try {
                                return_value = save_cover (new Gdk.Pixbuf.from_file (cover_full_path.get_path ()), 256);
                                cover_full_path.dispose ();
                                Idle.add ((owned) callback);
                                return null;
                            } catch (Error err) {
                                warning (err.message);
                            }
                        }
                    }
                }
                cover_full_path.dispose ();

                Gst.PbUtils.Discoverer discoverer;
                try {
                    discoverer = new Gst.PbUtils.Discoverer ((Gst.ClockTime) (5 * Gst.SECOND));
                } catch (Error err) {
                    warning (err.message);
                    Idle.add ((owned) callback);
                    return null;
                }

                foreach (var track in tracks) {
                    Gst.PbUtils.DiscovererInfo info;
                    try {
                        info = discoverer.discover_uri (track.uri);
                    } catch (Error err) {
                        continue;
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
                                return_value = save_cover (pixbuf, 256);
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
            return return_value;
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
