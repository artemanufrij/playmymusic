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

        public Volume volume { get; private set; }
        public string artist { get; private set; }

        string hash_sum = "";

        public new GLib.List<Track> tracks {
            get {
                return _tracks;
            }
        }

        public AudioCD (Volume volume) {
            this.volume = volume;
            this.title = _("Unknown");
            this.artist = _("Unknown");
            volume.mount.begin (MountMountFlags.NONE, null, null, (obj, res)=>{
                create_track_list ();
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
                        property_changed ("title");
                    }
                    string? album_artist = file_info.get_attribute_string (FILE_ATTRIBUTE_ARTIST);
                    if (album_artist != null) {
                        this.artist = album_artist.strip ();
                        property_changed ("artist");
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
                        track.track = counter;
                        track.title = title.strip ();
                        track.uri = GLib.Path.build_filename (file.get_uri (), file_info.get_name ());
                        track.duration = duration * 1000000000;
                        add_track (track);
                        counter++;
                    }
                    calculate_hash_sum ();
                } catch (Error err) {
                    warning (err.message);
                }
            });
        }

        private void calculate_hash_sum () {
            Checksum checksum = new Checksum (ChecksumType.MD5);
            FileStream stream = FileStream.open ("/dev/sr0", "r");
            uint8 fbuf[100];
            size_t size;
            while ((size = stream.read (fbuf)) > 0) {
                checksum.update (fbuf, size);
            }
            hash_sum = checksum.get_string ();
            stdout.printf ("%s\n", hash_sum);
        }
    }
}
