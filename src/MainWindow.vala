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

namespace PlayMyMusic {
    public class MainWindow : Gtk.Window {
        PlayMyMusic.Services.LibraryManager library_manager;
        PlayMyMusic.Settings settings;

        //CONTROLS
        Gtk.HeaderBar headerbar;
        Gtk.SearchEntry search_entry;
        Gtk.Spinner spinner;
        Gtk.Button play_button;
        Gtk.MenuItem menu_item_rescan;
        Gtk.Image icon_play;
        Gtk.Image icon_pause;

        Granite.Widgets.ModeButton view_mode;
        Widgets.Views.AlbumsView albums_view;
        Widgets.TrackTimeLine timeline;

        construct {
            settings = PlayMyMusic.Settings.get_default ();

            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            library_manager.tag_discover_started.connect (() => {
                spinner.active = true;
                menu_item_rescan.sensitive = false;
            });
            library_manager.tag_discover_finished.connect (() => {
                spinner.active = false;
                menu_item_rescan.sensitive = true;
            });

            library_manager.player_state_changed.connect ((state) => {
                if (state == Gst.State.PLAYING) {
                    play_button.image = icon_pause;
                    play_button.tooltip_text = _("Pause");
                    if (library_manager.player.current_track != null) {
                        timeline.set_playing_track (library_manager.player.current_track);
                        headerbar.set_custom_title (timeline);
                    } else if (library_manager.player.current_radio != null) {
                        play_button.sensitive = true;
                        headerbar.title = library_manager.player.current_radio.title;
                    }

                } else {
                    if (state == Gst.State.PAUSED) {
                        timeline.pause_playing ();
                    } else {
                        timeline.stop_playing ();
                        headerbar.set_custom_title (null);
                        headerbar.title = _("Play My Music");
                    }
                    play_button.image = icon_play;
                    play_button.tooltip_text = _("Play");
                }
            });
        }

        public MainWindow () {
            if (settings.window_maximized) {
                this.maximize ();
                this.set_default_size (1024, 720);
            } else {
                this.set_default_size (settings.window_width, settings.window_height);
            }
            build_ui ();

            albums_view.load_albums_from_database();

            this.configure_event.connect ((event) => {
                settings.window_width = event.width;
                settings.window_height = event.height;
                return false;
            });

            this.destroy.connect (() => {
                settings.window_maximized = this.is_maximized;
                settings.view_index = view_mode.selected;
            });
        }

        public void build_ui () {
            // CONTENT
            var content = new Gtk.Stack ();

            headerbar = new Gtk.HeaderBar ();
            headerbar.title = _("Play My Music");
            headerbar.show_close_button = true;
            this.set_titlebar (headerbar);

            // PLAY BUTTONS
            icon_play = new Gtk.Image.from_icon_name ("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            icon_pause = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            
            var previous_button = new Gtk.Button.from_icon_name ("media-skip-backward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            previous_button.tooltip_text = _("Previous");
            previous_button.sensitive = false;
            previous_button.clicked.connect (() => {
                library_manager.player.prev ();
            });

            play_button = new Gtk.Button ();
            play_button.image = icon_play;
            play_button.tooltip_text = _("Play");
            play_button.sensitive = false;
            play_button.clicked.connect (() => {
                play ();
            });

            var next_button = new Gtk.Button.from_icon_name ("media-skip-forward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            next_button.tooltip_text = _("Next");
            next_button.sensitive = false;
            next_button.clicked.connect (() => {
                library_manager.player.next ();
            });

            headerbar.pack_start (previous_button);
            headerbar.pack_start (play_button);
            headerbar.pack_start (next_button);

            // VIEW BUTTONS
            view_mode = new Granite.Widgets.ModeButton ();
            view_mode.valign = Gtk.Align.CENTER;
            view_mode.margin_left = 12;
            view_mode.append_icon ("view-grid-symbolic", Gtk.IconSize.BUTTON);
            //view_mode.append_icon ("view-list-compact-symbolic", Gtk.IconSize.BUTTON);
            view_mode.append_icon ("network-cellular-connected-symbolic", Gtk.IconSize.BUTTON);
            view_mode.mode_changed.connect (() => {
                switch (view_mode.selected) {
                    case 1:
                        if (library_manager.player.current_radio == null) {
                            search_entry.grab_focus ();
                        }
                        content.set_visible_child_name ("radios");
                        previous_button.sensitive = false;
                        next_button.sensitive = false;

                        break;
                    default:
                        content.set_visible_child_name ("albums");
                        if (albums_view.is_album_view_visible) {
                            previous_button.sensitive = true;
                            next_button.sensitive = true;
                        }
                        break;
                }
            });

            headerbar.pack_start (view_mode);

            // TIMELINE
            timeline = new Widgets.TrackTimeLine ();

            // SETTINGS MENU
            var app_menu = new Gtk.MenuButton ();
            app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR));

            var settings_menu = new Gtk.Menu ();
            var menu_item_import = new Gtk.MenuItem.with_label (_("Import to Library…"));
            menu_item_import.activate.connect (() => {
                var folder = library_manager.choose_folder ();
                if(folder != null) {
                    library_manager.scan_local_library (folder);
                }
            });

            menu_item_rescan = new Gtk.MenuItem.with_label (_("Rescan Library"));
            menu_item_rescan.activate.connect (() => {
                albums_view.reset ();
                library_manager.rescan_library ();
            });

            settings_menu.append (menu_item_import);
            settings_menu.append (new Gtk.SeparatorMenuItem ());
            settings_menu.append (menu_item_rescan);
            settings_menu.show_all ();

            app_menu.popup = settings_menu;
            headerbar.pack_end (app_menu);

            // SEARCH ENTRY
            search_entry = new Gtk.SearchEntry ();
            search_entry.placeholder_text = _("Search Music");
            search_entry.margin_right = 5;
            search_entry.search_changed.connect (() => {
                albums_view.filter (search_entry.text);
            });
            headerbar.pack_end (search_entry);

            // SPINNER
            spinner = new Gtk.Spinner ();
            headerbar.pack_end (spinner);

            albums_view = new Widgets.Views.AlbumsView ();
            albums_view.album_selected.connect (() => {
                previous_button.sensitive = true;
                play_button.sensitive = true;
                next_button.sensitive = true;
            });

            var radios_view = new Widgets.Views.RadiosView ();

            content.add_named (albums_view, "albums");
            content.add_named (radios_view, "radios");
            this.add (content);

            this.show_all ();

            albums_view.hide_album_details ();

            view_mode.set_active (settings.view_index);
            radios_view.unselect_all ();
            search_entry.grab_focus ();
        }

        public void play () {
            if (library_manager.player.current_track != null || library_manager.player.current_radio != null) {
                library_manager.player.toggle_playing ();
            } else {
                albums_view.play_selected_album ();
            }
        }
    }
}
