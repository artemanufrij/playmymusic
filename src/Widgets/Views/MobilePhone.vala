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

namespace PlayMyMusic.Widgets.Views {
    public class MobilePhone : Gtk.Revealer {
        Services.LibraryManager library_manager;

        public Objects.MobilePhone ? current_mobile_phone { get; private set; default = null; }
        public Granite.Widgets.SourceList folders { get; private set; }

        Gtk.Label title;
        Gtk.Image image;
        Gtk.ProgressBar progress;
        Gtk.Label message;
        Gtk.Spinner spinner;
        public bool stay_closed { get; private set; default = false; }

        construct {
            library_manager = Services.LibraryManager.instance;
            library_manager.mobile_phone_connected.connect (
                (mobile_phone) => {
                    show_mobile_phone (mobile_phone);
                        this.reveal_child = true;
                });
            library_manager.mobile_phone_disconnected.connect (
                (volume) => {
                    if (current_mobile_phone.volume == volume) {
                        this.reveal_child = false;
                        reset ();
                    }
                });
        }

        public MobilePhone () {
            build_ui ();

            const Gtk.TargetEntry[] targetentries = {{ "STRING", 0, 0 }};

            folders.enable_drag_dest (targetentries, Gdk.DragAction.COPY);
        }

        private void build_ui () {
            var header = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            header.margin = 12;
            header.spacing = 12;

            title = new Gtk.Label ("");
            title.ellipsize = Pango.EllipsizeMode.END;

            image = new Gtk.Image ();

            spinner = new Gtk.Spinner ();
            spinner.height_request = 48;

            progress = new Gtk.ProgressBar ();

            message = new Gtk.Label (_("Enable MTP on your mobile phone"));
            message.wrap = true;
            message.max_width_chars = 0;
            message.justify = Gtk.Justification.CENTER;
            message.margin_top = 12;
            message.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

            header.pack_start (title, false, false, 0);
            header.pack_start (image);
            header.pack_start (spinner);
            header.pack_start (progress);
            header.pack_start (message);

            folders = new Granite.Widgets.SourceList ();
            folders.hexpand = false;
            folders.events |= Gdk.EventMask.KEY_RELEASE_MASK;
            folders.key_release_event.connect (
                (key) => {
                    if (key.keyval == Gdk.Key.Delete && (folders.selected is Objects.MobilePhoneMusicFolder)) {
                        (folders.selected as Objects.MobilePhoneMusicFolder).delete ();
                    }
                    return true;
                });

            var close_button = new Gtk.Button.from_icon_name ("pane-hide-symbolic-rtl", Gtk.IconSize.BUTTON);
            close_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
            close_button.get_style_context ().add_class ("mobile-close-button");
            close_button.tooltip_text = _("Hide Mobile Panel");
            close_button.valign = Gtk.Align.START;
            close_button.halign = Gtk.Align.END;
            close_button.clicked.connect (
                () => {
                    this.reveal_child = false;
                    stay_closed = true;
                });

            var content = new Gtk.Grid ();
            content.attach (close_button, 0, 0);
            content.attach (header, 0, 0);
            content.attach (folders, 0, 1);
            content.attach (new Gtk.Separator (Gtk.Orientation.VERTICAL), 1, 0, 1, 2);

            this.transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;

            this.add (content);
            this.show_all ();
        }

        public void hide_spinner () {
            spinner.hide ();
        }

        public void show_mobile_phone (Objects.MobilePhone mobile_phone) {
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

            reset ();

            current_mobile_phone = mobile_phone;

            title.label = current_mobile_phone.volume.get_name ();
            image.set_from_gicon (current_mobile_phone.volume.get_icon (), Gtk.IconSize.DIALOG);

            current_mobile_phone.storage_calculated.connect (storage_calculated);
            current_mobile_phone.music_folder_found.connect (music_folder_found);
            current_mobile_phone.copy_progress.connect (copy_progress);
            current_mobile_phone.copy_finished.connect (copy_finished);
            current_mobile_phone.copy_started.connect (copy_started);
        }

        public void reset () {
            current_mobile_phone = null;
            stay_closed = false;
            folders.root.clear ();
            message.show ();
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
            message.hide ();
            music_folder.collapsible = false;

            Idle.add (
                () => {
                    folders.root.add (music_folder);
                    return false;
                });
        }
    }
}
