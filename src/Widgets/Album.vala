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
    public class Album : Gtk.FlowBoxChild {
        PlayMyMusic.Services.LibraryManager library_manager;

        public PlayMyMusic.Objects.Album album { get; private set; }
        public string title { get { return album.title; } }
        public int year { get { return album.year; } }

        Gtk.Image cover;
        Gtk.Menu menu;
        Gtk.Menu playlists;

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
        }

        public Album (PlayMyMusic.Objects.Album album) {
            this.album = album;

            build_ui ();

            this.album.cover_changed.connect (() => {
                cover.pixbuf = this.album.cover.scale_simple (128, 128, Gdk.InterpType.BILINEAR);
            });
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
            var menu_add_into_playlist = new Gtk.MenuItem.with_label (_("Add into Playlist"));
            menu.add (menu_add_into_playlist);
            playlists = new Gtk.Menu ();
            menu_add_into_playlist.set_submenu (playlists);

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

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
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

                menu.popup (null, null, null, evt.button, evt.time);
                return true;
            }
            return false;
        }
    }
}
