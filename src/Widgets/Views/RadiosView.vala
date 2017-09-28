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
    public class RadiosView : Gtk.Grid {
        PlayMyMusic.Services.LibraryManager library_manager;
        Gtk.Entry new_station_title;
        Gtk.Entry new_station_url;
        Gtk.Image new_station_cover;
        Gtk.Button new_station_save;
        Gtk.Popover add_new_station_popover;
        Gtk.Grid message_container;
        Gtk.Stack stack;
        Gtk.ScrolledWindow radios_scroll;

        Gtk.ListBox radios;

        GLib.Regex protocol_regex;

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            library_manager.player_state_changed.connect ((state) => {
                if (state == Gst.State.PLAYING && library_manager.player.current_radio == null) {
                    radios.unselect_all ();
                }
            });
            library_manager.added_new_radio.connect ((radio) => {
                var r = new Widgets.Radio (radio);
                r.show_all ();
                radios.add (r);
                stack.set_visible_child (radios_scroll);
            });
            library_manager.removed_radio.connect (() => {
                if (radios.get_children ().length () < 2) {
                    stack.set_visible_child (message_container);
                }
            });

            try {
                this.protocol_regex = new Regex ("""https?\:\/\/[\w+\d+]((\:\d+)?\/\S*)?""");
            } catch (RegexError err) {
                warning (err.message);
            }
        }

        public RadiosView () {
            this.map.connect (() => {
                grab_playing_radio ();
            });

            build_ui ();
        }

        private void build_ui () {
            radios = new Gtk.ListBox ();
            radios.set_sort_func (radio_sort_func);
            radios.selection_mode = Gtk.SelectionMode.SINGLE;
            radios.row_activated.connect (play_station);

            radios_scroll = new Gtk.ScrolledWindow (null, null);
            radios_scroll.add (radios);

            var radio_toolbar = new Gtk.ActionBar ();

            var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic");
            add_button.tooltip_text = _("Add a radio station");
            radio_toolbar.pack_start (add_button);

// NEW STATION POPOVER BEGIN
            var new_station = new Gtk.Grid ();
            new_station.row_spacing = 6;
            new_station.column_spacing = 12;
            new_station.margin = 12;

            new_station_title = new Gtk.Entry ();
            new_station_title.placeholder_text = "Station Name";
            new_station_title.changed.connect (() => {
                new_station_save.sensitive = valid_new_station ();
            });
            new_station.attach (new_station_title, 1, 0);

            new_station_url = new Gtk.Entry ();
            new_station_url.placeholder_text = "URL";
            new_station_url.changed.connect (() => {
                new_station_save.sensitive = valid_new_station ();
            });
            new_station.attach (new_station_url, 1, 1);

            new_station_cover = new Gtk.Image.from_icon_name ("network-cellular-connected-symbolic", Gtk.IconSize.DIALOG);
            new_station_cover.get_style_context ().add_class ("card");
            new_station.attach (new_station_cover, 0, 0, 1, 2);

            var new_station_controls = new Gtk.Grid ();
            new_station_controls.column_spacing = 6;
            new_station_controls.margin_top = 6;
            new_station_controls.column_homogeneous = true;
            new_station_controls.hexpand = true;

            var new_station_choose_cover = new Gtk.Button.with_label (_("Choose a Cover"));
            new_station_choose_cover.hexpand = true;
            new_station_choose_cover.clicked.connect (() => {
                var new_cover = library_manager.choose_new_cover ();
                if (new_cover != null) {
                    try {
                        new_station_cover.pixbuf = library_manager.align_and_scale_pixbuf (new Gdk.Pixbuf.from_file (new_cover), 48);
                    } catch (Error err) {
                        warning (err.message);
                    }
                }
            });
            new_station_controls.attach (new_station_choose_cover, 0, 0);

            new_station_save = new Gtk.Button.with_label (_("Add"));
            new_station_save.sensitive = false;
            new_station_save.hexpand = true;
            new_station_save.get_style_context ().add_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            new_station_save.clicked.connect (() => {
                save_new_station ();
            });
            new_station_controls.attach (new_station_save, 1, 0);

            new_station.attach (new_station_controls, 0, 2, 2, 1);

            add_new_station_popover = new Gtk.Popover (add_button);
            add_new_station_popover.position = Gtk.PositionType.TOP;
            add_new_station_popover.add (new_station);
            add_button.clicked.connect (() => {
                add_new_station_popover.show_all ();
            });
// NEW STATION POPOVER END

            message_container = new Gtk.Grid ();
            message_container.valign = Gtk.Align.CENTER;
            message_container.halign = Gtk.Align.CENTER;
            var message_title = new Gtk.Label (_("No Radio Stations"));
            message_title.get_style_context ().add_class ("h2");
            message_container.attach (message_title, 0, 0);
            var message_body = new Gtk.Label (_("Click the '+' button for adding a new Radion Station."));
            message_container.attach (message_body, 0, 1);

            stack = new Gtk.Stack ();
            stack.add (message_container);
            stack.add (radios_scroll);

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.expand = true;
            content.pack_start (stack, true, true, 0);
            content.pack_end (radio_toolbar, false, false, 0);

            this.add (content);
            this.show_all ();
            show_albums_from_database.begin ();
        }

        private bool valid_new_station () {
            var new_title = new_station_title.text.strip ();
            var new_url = new_station_url.text.down ().strip ();
            return new_title != "" && new_url != "" && this.protocol_regex.match (new_url) && !library_manager.radio_station_exists (new_url);
        }

        private void save_new_station () {
            var new_title = new_station_title.text.strip ();
            var new_url = new_station_url.text.down ().strip ();
            var new_radio = new PlayMyMusic.Objects.Radio.with_parameters (new_title, new_url, new_station_cover.pixbuf);
            library_manager.insert_new_radio_station (new_radio);
            add_new_station_popover.hide ();
            new_station_title.text = "";
            new_station_url.text = "";
            new_station_cover.set_from_icon_name ("network-cellular-connected-symbolic", Gtk.IconSize.DIALOG);
        }

        public void unselect_all () {
            radios.unselect_all ();
        }

        private void grab_playing_radio () {
            if (radios.get_selected_row () != null) {
                radios.get_selected_row ().activate ();
            }
        }

        public void play_station (Gtk.ListBoxRow item) {
            var radio = (item as PlayMyMusic.Widgets.Radio);
            library_manager.play_radio (radio.radio);
        }

        private async void show_albums_from_database () {
            foreach (var radio in library_manager.radios) {
                var r = new Widgets.Radio (radio);
                r.show_all ();
                radios.add (r);
            }

            if (radios.get_children ().length () > 0) {
                stack.set_visible_child (radios_scroll);
            }
        }

        private int radio_sort_func (Gtk.ListBoxRow child1, Gtk.ListBoxRow child2) {
            var item1 = (Widgets.Radio)child1;
            var item2 = (Widgets.Radio)child2;
            return item1.title.collate (item2.title);
        }
    }
}
