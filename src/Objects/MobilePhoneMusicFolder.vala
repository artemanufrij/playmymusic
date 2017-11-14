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
    public class MobilePhoneMusicFolder : GLib.Object {
        public signal void subfolder_created (File file);

        public string parent { get; private set; }
        public string title { get; private set; }
        public File file { get; private set; }

        public MobilePhoneMusicFolder (string uri) {
            this.file = File.new_for_uri (uri);
            this.title = file.get_basename ();
            this.parent = file.get_parent ().get_basename ();
        }

        public GLib.List<File> get_subfolders () {
            GLib.List<File> return_value = new GLib.List<File> ();

            try {
                var children = file.enumerate_children ("standard::*", GLib.FileQueryInfoFlags.NONE);
                FileInfo file_info = null;
                while ((file_info = children.next_file ()) != null) {
                    if (file_info.get_file_type () == FileType.DIRECTORY) {
                        return_value.append (File.new_for_uri (file.get_uri () + "/" + file_info.get_name ()));
                    }
                }
            } catch (Error err) {
                warning (err.message);
            }

            return return_value;
        }
    }
}
