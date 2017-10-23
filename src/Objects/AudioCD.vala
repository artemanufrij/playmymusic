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
    public class AudioCD : TracksContainer {
        const string FILE_ATTRIBUTE_TITLE = "xattr::org.gnome.audio.title";
        const string FILE_ATTRIBUTE_ARTIST = "xattr::org.gnome.audio.artist";
        const string FILE_ATTRIBUTE_DURATION = "xattr::org.gnome.audio.duration";

        public signal void mb_disc_id_calculated ();

        public Volume volume { get; private set; }
        public string artist { get; set; }

        string _mb_disc_id = "";
        public string mb_disc_id {
            get {
                return _mb_disc_id;
            } private set {
                _mb_disc_id = value;
                this.cover_path = GLib.Path.build_filename (PlayMyMusic.PlayMyMusicApp.instance.COVER_FOLDER, ("audio_cd_%s.jpg").printf (this.mb_disc_id));
                this.background_path = GLib.Path.build_filename (PlayMyMusic.PlayMyMusicApp.instance.COVER_FOLDER, ("audio_cd_%s_background.png").printf (this.mb_disc_id));
                load_cover_async.begin ();
                mb_disc_id_calculated ();
            }
        }

        public new GLib.List<Track> tracks {
            get {
                return _tracks;
            }
        }

        construct {
            this.cover_changed.connect (() => {
                ID = -1;
                create_background ();
            });
        }

        public AudioCD (Volume volume) {
            this.volume = volume;
            this.title = _("Unknown");
            this.artist = _("Unknown");
            volume.mount.begin (MountMountFlags.NONE, null, null, (obj, res)=>{
                create_track_list ();
                calculate_disc_id ();
            });
        }

        public void create_track_list () {
            var file = this.volume.get_activation_root ();
            var attributes = new string[0];
            attributes += FILE_ATTRIBUTE_TITLE;
            attributes += FILE_ATTRIBUTE_DURATION;
            attributes += FILE_ATTRIBUTE_ARTIST;
            attributes += FileAttribute.STANDARD_NAME;

            file.query_info_async.begin (string.joinv (",", attributes), FileQueryInfoFlags.NONE, Priority.DEFAULT, null, (obj, res) => {
                try {
                    FileInfo file_info = file.query_info_async.end (res);
                    string? album_title = file_info.get_attribute_string (FILE_ATTRIBUTE_TITLE);
                    if (album_title != null) {
                        this.title = album_title;
                    }
                    string? album_artist = file_info.get_attribute_string (FILE_ATTRIBUTE_ARTIST);
                    if (album_artist != null) {
                        this.artist = album_artist.strip ();
                    }

                    int counter = 1;
                    var children = file.enumerate_children (string.joinv (",", attributes), GLib.FileQueryInfoFlags.NONE);
                    while ((file_info = children.next_file ()) != null) {
                        string? title = file_info.get_attribute_string (FILE_ATTRIBUTE_TITLE);
                        if (title == null) {
                            title = _("Track %d").printf (counter);
                        }
                        uint64 duration = file_info.get_attribute_uint64 (FILE_ATTRIBUTE_DURATION);

                        var track = new Track (this);
                        track.ID = counter * -1;
                        track.track = counter;
                        track.title = title.strip ();
                        track.uri = GLib.Path.build_filename (file.get_uri (), file_info.get_name ());
                        track.duration = duration * 1000000000;
                        add_track (track);
                        counter++;
                    }
                } catch (Error err) {
                    warning (err.message);
                }
            });
        }

        public void update_track_title (int num, string title) {
            foreach (var track in tracks) {
                if (track.track == num) {
                    track.title = title;
                }
            }
        }

        private void calculate_disc_id () {
            new Thread<void*> (null, () => {
                dynamic Gst.Element source = null;
                try {
                    source = Gst.Element.make_from_uri (Gst.URIType.SRC, "cdda://", null);
                } catch (Error err) {
                    warning (err.message);
                }
                if (source == null) {
                    return null;
                }
                source.@set ("device", "/dev/cdrom", null);
                dynamic Gst.Element pipeline = new Gst.Pipeline (null);
                dynamic Gst.Element sink = Gst.ElementFactory.make ("fakesink", null);
                (pipeline as Gst.Bin).add_many (source, sink);
                source.link (sink);
                pipeline.set_state (Gst.State.PAUSED);
                Gst.Bus bus = pipeline.get_bus ();
                bool done = false;
                while (!done) {
                    Gst.Message? msg;
                    Gst.TagList tags;
                    GLib.Error err;
                    msg = bus.timed_pop (5 * Gst.SECOND);
                    if (msg == null) {
                        break;
                    }
                    switch (msg.type) {
                        case Gst.MessageType.TAG:
                            msg.parse_tag (out tags);
                            string s;
                            if (tags.get_string (Gst.Tag.CDDA.MUSICBRAINZ_DISCID, out s)) {
                                mb_disc_id = s;
                                stdout.printf ("MB DISC ID: %s\n", mb_disc_id);
                            }
                            done = true;
                            break;
                        case Gst.MessageType.ERROR:
                            string debug;
                            msg.parse_error (out err, out debug);
                            warning ("Error: %s\n%s\n", err.message, debug);
                            done = true;
                            break;
                        default:
                            break;
                    }
                }
                pipeline.set_state (Gst.State.NULL);
                return null;
            });
        }

        public async void load_cover_async () {
            var cover_full_path = File.new_for_path (cover_path);
            if (cover_full_path.query_exists ()) {
                try {
                    cover = new Gdk.Pixbuf.from_file (cover_path);
                } catch (Error err) {
                    warning (err.message);
                }
            }
        }
    }
}
