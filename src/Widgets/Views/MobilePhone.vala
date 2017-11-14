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

namespace PlayMyMusic.Widgets.Views {
    public class MobilePhone : Gtk.Grid {

        public PlayMyMusic.Objects.MobilePhone? current_mobile_phone { get; private set; default = null;}

        Gtk.Label title;
        Gtk.Image image;
        Gtk.ProgressBar progress;
        Gtk.Spinner spinner;
        Granite.Widgets.SourceList folders;

        string no_items = _("No Music Files");

        public MobilePhone () {
            build_ui ();
        }

        private void build_ui () {
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.margin = 12;
            content.spacing = 12;

            title = new Gtk.Label ("");
            title.ellipsize = Pango.EllipsizeMode.END;

            image = new Gtk.Image ();

            spinner = new Gtk.Spinner ();
            spinner.height_request = 48;

            progress = new Gtk.ProgressBar ();

            content.pack_start (title, false, false, 0);
            content.pack_start (image);
            content.pack_start (spinner);
            content.pack_start (progress);

            folders = new Granite.Widgets.SourceList ();
            folders.hexpand = false;
            folders.events |= Gdk.EventMask.KEY_RELEASE_MASK;
            folders.key_release_event.connect ((key) => {
                if (key.keyval == Gdk.Key.Delete) {
                     stdout.printf ("DELETE - %s\n", folders.selected.name);
                }
                return true;
            });

            this.attach (content, 0, 0);
            this.attach (folders, 0, 1);
            this.attach (new Gtk.Separator (Gtk.Orientation.VERTICAL), 1, 0, 1, 2);
            this.show_all ();
        }

        public void hide_spinner () {
            spinner.hide ();
        }

        public void show_mobile_phone (PlayMyMusic.Objects.MobilePhone mobile_phone) {
            if (current_mobile_phone == mobile_phone) {
                return;
            }

            if (current_mobile_phone != null) {
                current_mobile_phone.storage_calculated.disconnect (storage_calculated);
                current_mobile_phone.music_folder_found.disconnect (music_folder_found);
                current_mobile_phone.copy_progress.disconnect (copy_progress);
                current_mobile_phone.copy_finished.disconnect (copy_finished);
                current_mobile_phone.copy_started.disconnect (copy_started);
            }
            folders.root.clear ();
            current_mobile_phone = mobile_phone;

            title.label = current_mobile_phone.volume.get_name ();
            image.set_from_gicon (current_mobile_phone.volume.get_icon (), Gtk.IconSize.DIALOG);

            current_mobile_phone.storage_calculated.connect (storage_calculated);
            current_mobile_phone.music_folder_found.connect (music_folder_found);
            current_mobile_phone.copy_progress.connect (copy_progress);
            current_mobile_phone.copy_finished.connect (copy_finished);
            current_mobile_phone.copy_started.connect (copy_started);
        }

        private void storage_calculated () {
            progress.fraction = 1 - (double)1 / current_mobile_phone.size * current_mobile_phone.free;
        }

        private void copy_progress (string title, uint count, uint sum) {
            progress.fraction = (double)1 / sum * count;
        }

        private void copy_finished () {
            image.show ();
            spinner.hide ();
            spinner.active = false;
            storage_calculated ();
        }

        private void copy_started () {
            image.hide ();
            spinner.show ();
            spinner.active = true;
        }

        private void music_folder_found (Objects.MobilePhoneMusicFolder music_folder) {

            var folder = new Granite.Widgets.SourceList.ExpandableItem (music_folder.parent);
            folder.collapsible = false;
            folder.expand_all ();

            foreach (var item in music_folder.get_subfolders ()) {
                var subfolder = new Granite.Widgets.SourceList.ExpandableItem (item.get_basename ());
                folder.add (subfolder);
            }
            music_folder.subfolder_created.connect ((file) => {
                Idle.add (() => {
                    var subfolder = new Granite.Widgets.SourceList.ExpandableItem (file.get_basename ());
                    folder.add (subfolder);
                    foreach (var child in folder.children){
                        if (child.name == no_items) {
                            folder.remove (child);
                            break;
                        }
                    }
                    return false;
                });
            });

            if (folder.children.size == 0) {
                folder.add (new Granite.Widgets.SourceList.Item (no_items));
            }

            Idle.add (() => {
                folders.root.add (folder);
                return false;
            });
        }
    }
}
