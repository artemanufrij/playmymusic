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
    public class MobilePhone : GLib.Object {
        public Volume volume { get; private set; }

        public signal void music_folder_found (string uri);
        public signal void storage_calculated ();

        public uint64 size { get; private set; }
        public uint64 free { get; private set; }

        public MobilePhone (Volume volume) {
            this.volume = volume;
            this.volume.mount.begin (MountMountFlags.NONE, null, null, (obj, res) => {
                try {
                    var info = volume.get_activation_root ().query_filesystem_info ("filesystem::*");
                    free = info.get_attribute_uint64 ("filesystem::free");
                    size = info.get_attribute_uint64 ("filesystem::size");
                    storage_calculated ();
                    found_music_folder (volume.get_activation_root ().get_uri ());

                } catch (Error err) {
                    warning (err.message);
                }
            });
        }

        public void found_music_folder (string uri) {
            new Thread <void*> (null, () => {
                var file = File.new_for_uri (uri);
                var children = file.enumerate_children ("standard::*", GLib.FileQueryInfoFlags.NONE);
                FileInfo file_info = null;

                while ((file_info = children.next_file ()) != null) {
                    if (file_info.get_file_type () == FileType.DIRECTORY) {
                        if (file_info.get_name ().down () == "music") {
                            music_folder_found (uri + file_info.get_name () + "/");
                        } else {
                            found_music_folder (uri + file_info.get_name () + "/");
                        }
                    }
                }
                return null;
            });
        }

        public GLib.List<File> get_subfolders (string uri) {
            GLib.List<File> return_value = new GLib.List<File> ();

            var file = File.new_for_uri (uri);
            var children = file.enumerate_children ("standard::*", GLib.FileQueryInfoFlags.NONE);
            FileInfo file_info = null;

            while ((file_info = children.next_file ()) != null) {
                if (file_info.get_file_type () == FileType.DIRECTORY) {
                    return_value.append (File.new_for_uri (uri + file_info.get_name () + "/"));
                }
            }

            return return_value;
        }
    }
}
