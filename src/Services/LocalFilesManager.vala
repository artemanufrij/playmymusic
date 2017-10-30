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
    public class LocalFilesManager : GLib.Object {
        static LocalFilesManager _instance = null;
        public static LocalFilesManager instance {
            get {
                if (_instance == null) {
                    _instance = new LocalFilesManager ();
                }
                return _instance;
            }
        }

        public signal void scan_started ();
        public signal void found_music_file (string path);

        private LocalFilesManager () { }

        public void scan (string path) {
            scan_started ();
            scan_local_files (path);
        }

        private void scan_local_files (string path) {
            new Thread<void*> (null, () => {
                File directory = File.new_for_path (path);
                try {
                    var children = directory.enumerate_children (FileAttribute.STANDARD_CONTENT_TYPE + "," + FileAttribute.STANDARD_IS_HIDDEN + "," + FileAttribute.STANDARD_IS_SYMLINK + "," + FileAttribute.STANDARD_SYMLINK_TARGET, GLib.FileQueryInfoFlags.NONE);
                    FileInfo file_info;

                    while ((file_info = children.next_file ()) != null) {
                        if (file_info.get_is_hidden ()) {
                            continue;
                        }

                        if (file_info.get_is_symlink ()) {
                            string target = file_info.get_symlink_target ();
                            var symlink = File.new_for_path (target);
                            var file_type = symlink.query_file_type (0);
                            if (file_type == FileType.DIRECTORY) {
                                scan_local_files (target);
                            }
                        } else if (file_info.get_file_type () == FileType.DIRECTORY) {
                            scan_local_files (GLib.Path.build_filename (path, file_info.get_name ()));
                        } else {
                            string mime_type = file_info.get_content_type ();
                            bool valid_file = !file_info.get_is_hidden () && mime_type.has_prefix ("audio/") && !mime_type.contains ("x-mpegurl") && !mime_type.contains ("x-scpls");
                            if (valid_file) {
                                string found_path = GLib.Path.build_filename (path, file_info.get_name ());
                                found_music_file (found_path);
                            }
                        }
                    }
                    children.close ();
                    children.dispose ();
                } catch (Error err) {
                    warning (err.message);
                }
                directory.dispose ();
                return null;
            });
        }
    }
}
