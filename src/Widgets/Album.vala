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

namespace PlayMyMusic.Widgets {
    public class Album : Gtk.FlowBoxChild {
        PlayMyMusic.Services.LibraryManager library_manager;
        PlayMyMusic.Settings settings;

        public signal void merge ();

        public PlayMyMusic.Objects.Album album { get; private set; }
        public string title { get { return album.title; } }
        public int year { get { return album.year; } }

        Gtk.Image cover;
        Gtk.Label title_label;
        Gtk.Menu menu = null;
        Gtk.Menu playlists;
        Gtk.Menu send_to;
        Gtk.MenuItem menu_send_to;
        Gtk.MenuItem menu_merge;
        Gtk.Button multi_select;
        Gtk.Image add_selection_image;
        Gtk.Image multi_selected_image;

        public bool multi_selection { get; private set; default = false; }

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            settings = PlayMyMusic.Settings.get_default ();
        }

        public Album (PlayMyMusic.Objects.Album album) {
            this.album = album;
            this.draw.connect (first_draw);

            build_ui ();

            this.album.cover_changed.connect (() => {
                Idle.add (() => {
                    cover.pixbuf = this.album.cover.scale_simple (128, 128, Gdk.InterpType.BILINEAR);
                    return false;
                });
            });
            this.album.removed.connect (() => {
                Idle.add (() => {
                    this.destroy ();
                    return false;
                });
            });
            this.album.updated.connect (() => {
                set_values ();
            });
            this.key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.F2) {
                    edit_album ();
                    return true;
                }
                return false;
            });
        }

        private bool first_draw () {
            this.draw.disconnect (first_draw);
            if (this.album.cover == null) {
                cover.set_from_icon_name ("audio-x-generic-symbolic", Gtk.IconSize.DIALOG);
            } else {
                cover.pixbuf = this.album.cover.scale_simple (128, 128, Gdk.InterpType.BILINEAR);
            }
            return false;
        }

        private void build_ui () {
            const Gtk.TargetEntry[] targetentries = {{ "STRING", 0, 0 }};

            var event_box = new Gtk.EventBox ();
            Gtk.drag_source_set (event_box, Gdk.ModifierType.BUTTON1_MASK, targetentries, Gdk.DragAction.COPY);
            event_box.button_press_event.connect (show_context_menu);
            event_box.drag_data_get.connect (on_drag_data_get);
            event_box.drag_begin.connect (on_drag_begin);
            event_box.enter_notify_event.connect ((event) => {
                multi_select.opacity = 1;
                return false;
            });
            event_box.leave_notify_event.connect ((event) => {
                if (!this.is_selected ()) {
                    multi_select.opacity = 0;
                }
                return false;
            });

            var content = new Gtk.Grid ();
            content.margin = 12;
            content.halign = Gtk.Align.CENTER;
            content.row_spacing = 6;
            event_box.add (content);

            cover = new Gtk.Image ();
            cover.get_style_context ().add_class ("card");
            cover.halign = Gtk.Align.CENTER;
            cover.height_request = 128;
            cover.width_request = 128;

            title_label = new Gtk.Label ("");
            title_label.opacity = 0.5;
            title_label.use_markup = true;
            title_label.halign = Gtk.Align.FILL;
            title_label.ellipsize = Pango.EllipsizeMode.END;
            title_label.max_width_chars = 0;

            var artist = new Gtk.Label (this.album.artist.name);
            artist.halign = Gtk.Align.FILL;
            artist.ellipsize = Pango.EllipsizeMode.END;
            artist.max_width_chars = 0;

            // MULTISELECTION BUTTON
            add_selection_image = new Gtk.Image.from_icon_name ("selection-add", Gtk.IconSize.BUTTON);
            multi_selected_image = new Gtk.Image.from_icon_name ("selection-checked", Gtk.IconSize.BUTTON);

            multi_select = new Gtk.Button ();
            multi_select.valign = Gtk.Align.START;
            multi_select.halign = Gtk.Align.START;
            multi_select.get_style_context ().remove_class ("button");
            multi_select.set_image (add_selection_image);
            multi_select.can_focus = false;
            multi_select.opacity = 0;
            multi_select.clicked.connect (() => {
                toggle_multi_selection ();
            });
            multi_select.enter_notify_event.connect ((event) => {
                multi_select.opacity = 1;
                return false;
            });

            content.attach (multi_select, 0, 0);
            content.attach (cover, 0, 0);
            content.attach (title_label, 0, 1);
            content.attach (artist, 0, 2);

            this.add (event_box);
            this.valign = Gtk.Align.START;

            set_values ();

            this.show_all ();
        }

        public void toggle_multi_selection (bool activate = true) {
            if (!multi_selection) {
                multi_selection = true;
                if (activate) {
                    this.activate ();
                }
                multi_select.opacity = 1;
                multi_select.set_image (multi_selected_image);
            } else {
                multi_selection = false;
                (this.parent as Gtk.FlowBox).unselect_child (this);
                multi_select.set_image (add_selection_image);
            }
        }

        private void set_values () {
            this.tooltip_markup = ("<b>%s</b>%s\n%s").printf (album.title.replace ("&", "&amp;"), year > 0 ? (" (%d)").printf (year) :"", album.artist.name.replace ("&", "&amp;"));
            title_label.label = ("<b>%s</b>").printf (this.title.replace ("&", "&amp;"));
            this.changed ();
        }

        public void reset () {
            multi_select.set_image (add_selection_image);
            multi_select.opacity = 0;
            multi_selection = false;
        }

        private void on_drag_data_get (Gdk.DragContext context, Gtk.SelectionData selection_data, uint target_type, uint time) {
            selection_data.set_text ("Album:%d".printf (this.album.ID), -1);
        }

        private void on_drag_begin (Gdk.DragContext context) {
            if (this.album.cover_32 != null) {
                var surface = new Granite.Drawing.BufferSurface (32, 32);
                Gdk.cairo_set_source_pixbuf (surface.context, this.album.cover_32, 0, 0);
                surface.context.paint ();
                Gtk.drag_set_icon_surface (context, surface.surface);
            }
        }

        private void edit_album () {
            var editor = new Dialogs.AlbumEditor (PlayMyMusicApp.instance.mainwindow, this.album);
            if (editor.run () == Gtk.ResponseType.ACCEPT) {
                editor.destroy ();
            }
        }

        private void build_context_menu () {
            menu = new Gtk.Menu ();
            var menu_new_cover = new Gtk.MenuItem.with_label (_("Set new Cover…"));
            menu_new_cover.activate.connect (() => {
                var new_cover = library_manager.choose_new_cover ();
                if (new_cover != null) {
                    try {
                        var pixbuf = new Gdk.Pixbuf.from_file (new_cover);
                        album.set_new_cover (pixbuf, 256);
                        if (settings.save_custom_covers) {
                            album.set_custom_cover_file (new_cover);
                        }
                    } catch (Error err) {
                        warning (err.message);
                    }
                }
            });
            menu.add (menu_new_cover);

            var menu_edit_album = new Gtk.MenuItem.with_label (_("Edit Album properties…"));
            menu_edit_album.activate.connect (() => {
                edit_album ();
            });
            menu.add (menu_edit_album);
            menu.add (new Gtk.SeparatorMenuItem ());

            var menu_add_into_playlist = new Gtk.MenuItem.with_label (_("Add into Playlist"));
            menu.add (menu_add_into_playlist);
            playlists = new Gtk.Menu ();
            menu_add_into_playlist.set_submenu (playlists);

            menu_send_to = new Gtk.MenuItem.with_label (_("Send to"));
            menu.add (menu_send_to);
            send_to = new Gtk.Menu ();
            menu_send_to.set_submenu (send_to);

            menu_merge = new Gtk.MenuItem.with_label (_("Merge selected Albums"));
            menu_merge.activate.connect (() => {
                merge ();
            });
            menu.add (menu_merge);

            menu.show_all ();
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {

                if (menu == null) {
                    build_context_menu ();
                }

                this.activate ();
                // PLAYLISTS
                foreach (var child in playlists.get_children ()) {
                    child.destroy ();
                }
                var item = new Gtk.MenuItem.with_label (_("Create New Playlist"));
                item.activate.connect (() => {
                    var new_playlist = library_manager.create_new_playlist ();
                    foreach (var track in album.tracks) {
                        library_manager.add_track_into_playlist (new_playlist, track.ID);
                    }
                });
                playlists.add (item);
                if (library_manager.playlists.length () > 0) {
                    playlists.add (new Gtk.SeparatorMenuItem ());
                }
                foreach (var playlist in library_manager.playlists) {
                    item = new Gtk.MenuItem.with_label (playlist.title);
                    item.activate.connect (() => {
                        foreach (var track in album.tracks) {
                            library_manager.add_track_into_playlist (playlist, track.ID);
                        }
                    });
                    playlists.add (item);
                }
                playlists.show_all ();

                // SEND TO
                foreach (var child in send_to.get_children ()) {
                    child.destroy ();
                }

                var current_mobile_phone = PlayMyMusicApp.instance.mainwindow.mobile_phone_view.current_mobile_phone;
                if (current_mobile_phone != null) {
                    foreach (var music_folder in current_mobile_phone.music_folders) {
                        item = new Gtk.MenuItem.with_label (music_folder.name);
                        item.activate.connect (() => {
                            current_mobile_phone.add_album (album, music_folder);
                        });
                        send_to.add (item);
                    }
                }
                if (send_to.get_children ().length () == 0) {
                    menu_send_to.hide ();
                } else {
                    menu_send_to.show_all ();
                }

                // MERGE
                if ((this.parent as Gtk.FlowBox).get_selected_children ().length () > 1) {
                    menu_merge.show_all ();
                } else {
                    menu_merge.hide ();
                }

                menu.popup (null, null, null, evt.button, evt.time);
                return true;
            } else if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 1) {
                this.activate ();
                return true;
            }
            return false;
        }
    }
}
