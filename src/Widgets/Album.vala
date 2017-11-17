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

namespace PlayMyMusic.Widgets {

    enum Target {
        INT32,
        STRING,
        ROOTWIN
    }

    const Gtk.TargetEntry[] targets = {
        { "INTEGER",    0, Target.INT32 },
        { "STRING",     0, Target.STRING },
        { "text/plain", 0, Target.STRING },
        { "*", 0, Target.ROOTWIN }
    };

    public class Album : Gtk.FlowBoxChild {
        PlayMyMusic.Services.LibraryManager library_manager;

        public PlayMyMusic.Objects.Album album { get; private set; }
        public string title { get { return album.title; } }
        public int year { get { return album.year; } }

        Gtk.Image cover;
        Gtk.Menu menu;
        Gtk.Menu playlists;
        Gtk.Menu send_to;
        Gtk.MenuItem menu_send_to;

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
        }

        public Album (PlayMyMusic.Objects.Album album) {
            this.album = album;

            build_ui ();

            this.album.cover_changed.connect (() => {
                Idle.add (() => {
                    cover.pixbuf = this.album.cover.scale_simple (128, 128, Gdk.InterpType.BILINEAR);
                    return false;
                });
            });

            Gtk.drag_source_set (this, Gdk.ModifierType.BUTTON1_MASK, targets, Gdk.DragAction.COPY);
            this.drag_begin.connect (on_drag_begin);
            this.drag_data_get.connect (on_drag_data_get);
            this.drag_data_delete.connect (on_drag_data_delete);
            this.drag_end.connect (on_drag_end);
        }

        private void build_ui () {
            this.tooltip_markup = ("<b>%s</b>\n%s").printf (album.title.replace ("&", "&amp;"), album.artist.name.replace ("&", "&amp;"));

            var event_box = new Gtk.EventBox ();
            event_box.button_press_event.connect (show_context_menu);

            var content = new Gtk.Grid ();
            content.margin = 12;
            content.halign = Gtk.Align.CENTER;
            content.row_spacing = 6;
            event_box.add (content);

            menu = new Gtk.Menu ();
            var menu_new_cover = new Gtk.MenuItem.with_label (_("Set new Cover…"));
            menu_new_cover.activate.connect (() => {
                var new_cover = library_manager.choose_new_cover ();
                if (new_cover != null) {
                    try {
                        var pixbuf = new Gdk.Pixbuf.from_file (new_cover);
                        album.set_new_cover (pixbuf, 256);
                    } catch (Error err) {
                        warning (err.message);
                    }
                }
            });
            menu.add (menu_new_cover);

            var menu_add_into_playlist = new Gtk.MenuItem.with_label (_("Add into Playlist"));
            menu.add (menu_add_into_playlist);
            playlists = new Gtk.Menu ();
            menu_add_into_playlist.set_submenu (playlists);

            menu_send_to = new Gtk.MenuItem.with_label (_("Send to"));
            menu.add (menu_send_to);
            send_to = new Gtk.Menu ();
            menu_send_to.set_submenu (send_to);

            menu.show_all ();

            cover = new Gtk.Image ();
            cover.get_style_context ().add_class ("card");
            cover.halign = Gtk.Align.CENTER;
            if (this.album.cover == null) {
                cover.set_from_icon_name ("audio-x-generic-symbolic", Gtk.IconSize.DIALOG);
                cover.height_request = 128;
                cover.width_request = 128;
            } else {
                cover.pixbuf = this.album.cover.scale_simple (128, 128, Gdk.InterpType.BILINEAR);
            }

            var title = new Gtk.Label (("<span color='#666666'><b>%s</b></span>").printf (this.title.replace ("&", "&amp;")));
            title.use_markup = true;
            title.halign = Gtk.Align.FILL;
            title.ellipsize = Pango.EllipsizeMode.END;
            title.max_width_chars = 0;

            var artist = new Gtk.Label (this.album.artist.name);
            artist.halign = Gtk.Align.FILL;
            artist.ellipsize = Pango.EllipsizeMode.END;
            artist.max_width_chars = 0;

            content.attach (cover, 0, 0);
            content.attach (title, 0, 1);
            content.attach (artist, 0, 2);

            this.add (event_box);
            this.valign = Gtk.Align.START;

            this.show_all ();
        }

        private void on_drag_begin (Gdk.DragContext context) {
            stdout.printf ("%s: on_drag_begin\n", this.album.title);
        }

        private void on_drag_data_get (Gdk.DragContext context, Gtk.SelectionData selection_data, uint target_type, uint time) {
            stdout.printf ("%s: on_drag_data_get\n", this.album.title);
            uchar [] buf;
            convert_long_to_bytes (this.album.ID, out buf);
            selection_data.set (selection_data.get_target(), 16, buf);
        }

        private void on_drag_data_delete (Gdk.DragContext context) {
            stdout.printf ("%s: on_drag_data_delete\n", this.album.title);
        }

        private void on_drag_end (Gdk.DragContext context) {
            stdout.printf ("%s: on_drag_end\n", this.album.title);
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
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

                menu.popup (null, null, null, evt.button, evt.time);
                return true;
            }
            return false;
        }

        private void convert_long_to_bytes(long number, out uchar [] buffer) {
            buffer = new uchar [sizeof (long)];
            for (int i = 0; i < sizeof (long); i++) {
                buffer[i] = (uchar) (number & 0xFF);
                number = number >> 8;
            }
        }
    }
}
