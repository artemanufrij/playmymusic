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
    public class RadiosView : Gtk.Grid {
        Services.LibraryManager library_manager;

        private string _filter = "";
        public string filter {
            get {
                return _filter;
            } set {
                if (_filter != value) {
                    _filter = value;
                    do_filter ();
                }
            }
        }

        Gtk.Entry new_station_title;
        Gtk.Entry new_station_url;
        Gtk.Image new_station_cover;
        Gtk.Button new_station_save;
        Gtk.Popover add_new_station_popover;
        Gtk.Stack stack;
        Gtk.FlowBox radios;

        GLib.Regex protocol_regex;

        Objects.Radio current_edit_station;

        uint items_found = 0;

        construct {
            library_manager = Services.LibraryManager.instance;
            library_manager.player_state_changed.connect ((state) => {
                if (state == Gst.State.PLAYING ) {
                    if (library_manager.player.current_radio != null) {
                        grab_playing_radio ();
                    } else {
                        radios.unselect_all ();
                    }
                }
            });
            library_manager.added_new_radio.connect ((radio) => {
                add_radion (radio);
                stack.visible_child_name = "content";
            });
            library_manager.removed_radio.connect (() => {
                if (radios.get_children ().length () < 2) {
                    stack.visible_child_name = "welcome";
                }
            });

            try {
                this.protocol_regex = new Regex ("""https?\:\/\/[\w+\d+]((\:\d+)?\/\S*)?""");
            } catch (RegexError err) {
                warning (err.message);
            }
        }

        public RadiosView () {
            build_ui ();
        }

        private void build_ui () {
            radios = new Gtk.FlowBox ();
            radios.set_filter_func (radios_filter_func);
            radios.set_sort_func (radio_sort_func);
            radios.selection_mode = Gtk.SelectionMode.SINGLE;
            radios.margin = 24;
            radios.homogeneous = true;
            radios.row_spacing = 12;
            radios.column_spacing = 24;
            radios.max_children_per_line = 24;
            radios.child_activated.connect (play_station);
            radios.valign = Gtk.Align.START;

            var radios_scroll = new Gtk.ScrolledWindow (null, null);
            radios_scroll.add (radios);

            var action_toolbar = new Gtk.ActionBar ();
            action_toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);

            var add_button = new Gtk.Button.from_icon_name ("list-add-symbolic");
            add_button.tooltip_text = _ ("Add a radio station");
            action_toolbar.pack_start (add_button);

// NEW STATION POPOVER BEGIN
            var new_station = new Gtk.Grid ();
            new_station.row_spacing = 6;
            new_station.column_spacing = 6;
            new_station.margin = 12;

            new_station_title = new Gtk.Entry ();
            new_station_title.placeholder_text = _ ("Station Name");
            new_station_title.changed.connect (() => {
                new_station_save.sensitive = valid_new_station ();
            });
            new_station.attach (new_station_title, 1, 0);

            new_station_url = new Gtk.Entry ();
            new_station_url.placeholder_text = _ ("URL");
            new_station_url.changed.connect (() => {
                new_station_save.sensitive = valid_new_station ();
            });
            new_station.attach (new_station_url, 1, 1);

            var new_station_cover_event_box = new Gtk.EventBox ();
            new_station_cover_event_box.button_press_event.connect (() => {
                var new_cover = library_manager.choose_new_cover ();
                if (new_cover != null) {
                    try {
                        new_station_cover.pixbuf = library_manager.align_and_scale_pixbuf (new Gdk.Pixbuf.from_file (new_cover), 64);
                    } catch (Error err) {
                        warning (err.message);
                    }
                }
                return false;
            });
            new_station_cover = new Gtk.Image ();
            new_station_cover.tooltip_text = _("Click to choose a new cover…");
            new_station_cover.width_request = 64;
            new_station_cover.height_request = 64;
            new_station_cover_event_box.add (new_station_cover);
            new_station.attach (new_station_cover_event_box, 0, 0, 1, 2);

            new_station_save = new Gtk.Button ();
            new_station_save.sensitive = false;
            new_station_save.halign = Gtk.Align.END;
            new_station_save.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            new_station_save.clicked.connect (() => {
                save_new_station ();
            });

            new_station.attach (new_station_save, 0, 2, 2, 1);

            add_new_station_popover = new Gtk.Popover (null);
            add_new_station_popover.add (new_station);
            add_new_station_popover.key_press_event.connect ((event) => {
                if ((event.keyval == Gdk.Key.Return || event.keyval == Gdk.Key.KP_Enter) && Gdk.ModifierType.CONTROL_MASK in event.state && valid_new_station ()) {
                    save_new_station ();
                }
                return false;
            });
            add_button.clicked.connect (() => {
                add_new_station_popover.set_relative_to (add_button);
                var r = new Objects.Radio ();
                    edit_station (r);
            });
// NEW STATION POPOVER END

            var welcome = new Granite.Widgets.Welcome (_ ("No Radio Stations"), _ ("Add radio stations to your library."));
            welcome.append ("insert-link", _ ("Add Radio Station"), _ ("Add a Stream URL like .pls or .m3u."));
            welcome.activated.connect ((index) => {
                switch (index) {
                case 0 :
                    add_new_station_popover.set_relative_to (welcome.get_button_from_index (index));
                    var r = new Objects.Radio ();
                    edit_station (r);
                    break;
                }
            });

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.expand = true;
            content.pack_start (radios_scroll, true, true, 0);
            content.pack_end (action_toolbar, false, false, 0);

            var alert_view = new Granite.Widgets.AlertView (_ ("No results"), _ ("Try another search"), "edit-find-symbolic");

            stack = new Gtk.Stack ();
            stack.add_named (welcome, "welcome");
            stack.add_named (content, "content");
            stack.add_named (alert_view, "alert");

            this.add (stack);
            this.show_all ();
            show_radios_from_database.begin ();
        }

        private void add_radion (Objects.Radio radio) {
            var r = new Widgets.Radio (radio);
            r.show_all ();
            r.edit_request.connect (() => {
                add_new_station_popover.set_relative_to (r);
                edit_station (r.radio);
            });
            radios.add (r);
        }

        private bool valid_new_station () {
            var new_title = new_station_title.text.strip ();
            var new_url = new_station_url.text.down ().strip ();
            Objects.Radio ? db_radio = library_manager.db_manager.get_radio_by_url (new_url);
            return new_title != "" && new_url != "" && this.protocol_regex.match (new_url) && (db_radio == null || db_radio.ID == current_edit_station.ID);
        }

        private void edit_station (Objects.Radio radio) {
            current_edit_station = radio;
            new_station_cover.pixbuf = radio.cover;
            new_station_title.text = radio.title;
            new_station_url.text = radio.url;
            if (radio.ID == 0) {
                new_station_save.label = _ ("Add");
            } else {
                new_station_save.label = _ ("Save");
            }

            if (radio.cover == null) {
                new_station_cover.set_from_icon_name ("internet-radio-symbolic", Gtk.IconSize.DIALOG);
            } else {
                new_station_cover.pixbuf = radio.cover;
            }

            add_new_station_popover.show_all ();
        }

        private void save_new_station () {
            current_edit_station.title = new_station_title.text.strip ();
            current_edit_station.url = new_station_url.text.down ().strip ();
            current_edit_station.cover = new_station_cover.pixbuf;
            library_manager.save_radio_station (current_edit_station);
            add_new_station_popover.hide ();
            radios.unselect_all ();
        }

        public void reset () {
            filter = "";
            foreach (var child in radios.get_children ()) {
                radios.remove (child);
            }
            stack.visible_child_name = "welcome";
        }

        public void unselect_all () {
            radios.unselect_all ();
        }

        private void grab_playing_radio () {
            foreach (var item in radios.get_children ()) {
                if ((item as Widgets.Radio).radio == library_manager.player.current_radio) {
                    item.activate ();
                    return;
                }
            }
            radios.unselect_all ();
        }

        private void play_station (Gtk.FlowBoxChild item) {
            var radio = (item as Widgets.Radio).radio;
            library_manager.play_radio (radio);
        }

        private async void show_radios_from_database () {
            foreach (var radio in library_manager.radios) {
                add_radion (radio);
            }

            if (radios.get_children ().length () > 0) {
                stack.visible_child_name = "content";
            }
        }

        private void do_filter () {
            if (stack.visible_child_name == "welcome") {
                return;
            }

            items_found = 0;
            radios.invalidate_filter ();
            if (items_found == 0) {
                stack.visible_child_name = "alert";
            } else {
                stack.visible_child_name = "content";
            }
        }

        private bool radios_filter_func (Gtk.FlowBoxChild child) {
            if (filter.strip ().length == 0) {
                items_found++;
                return true;
            }

            string[] filter_elements = filter.strip ().down ().split (" ");
            var radio = (child as Widgets.Radio).radio;

            foreach (string filter_element in filter_elements) {
                if (!radio.title.down ().contains (filter_element) && !radio.url.down ().contains (filter_element)) {
                    return false;
                }
            }
            items_found++;
            return true;
        }

        private int radio_sort_func (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
            var item1 = (Widgets.Radio)child1;
            var item2 = (Widgets.Radio)child2;
            return item1.title.collate (item2.title);
        }
    }
}
