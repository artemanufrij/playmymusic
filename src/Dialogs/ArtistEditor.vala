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

namespace PlayMyMusic.Dialogs {
    public class ArtistEditor : Gtk.Dialog {
        PlayMyMusic.Services.LibraryManager library_manager;
        PlayMyMusic.Services.DataBaseManager db_manager;
        PlayMyMusic.Settings settings;
        Objects.Artist artist;

        Gtk.Image cover;
        Gtk.Entry name_entry;

        bool cover_changed = false;
        string? new_cover_path = null;

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            db_manager = PlayMyMusic.Services.DataBaseManager.instance;
            settings = PlayMyMusic.Settings.get_default ();
        }

        public ArtistEditor (Gtk.Window parent, Objects.Artist artist) {
            Object (
                transient_for: parent
            );
            this.artist = artist;
            build_ui ();

            this.response.connect ((source, response_id) => {
                switch (response_id) {
                    case Gtk.ResponseType.ACCEPT:
                        save ();
                    break;
                }
            });
            this.key_press_event.connect ((event) => {
                if ((event.keyval == Gdk.Key.Return || event.keyval == Gdk.Key.KP_Enter) && Gdk.ModifierType.CONTROL_MASK in event.state) {
                    save ();
                }
                return false;
            });
        }

        private void build_ui () {
            this.resizable = false;
            var content = get_content_area () as Gtk.Box;

            var grid = new Gtk.Grid ();
            grid.column_spacing = 12;
            grid.row_spacing = 12;
            grid.margin = 12;

            var event_box = new Gtk.EventBox ();

            cover = new Gtk.Image ();
            cover.tooltip_text = _("Click to choose a new cover…");
            event_box.button_press_event.connect ((event) => {
                new_cover_path = library_manager.choose_new_cover ();
                if (new_cover_path != null) {
                    try {
                        cover.pixbuf = library_manager.align_and_scale_pixbuf (new Gdk.Pixbuf.from_file (new_cover_path), 256);
                        cover_changed = true;
                    } catch (Error err) {
                        warning (err.message);
                    }
                }
                return false;
            });
            if (artist.cover == null) {
                cover.set_from_icon_name ("audio-x-generic-symbolic", Gtk.IconSize.DIALOG);
                cover.height_request = 256;
                cover.width_request = 256;
            } else {
                cover.pixbuf = artist.cover;
            }

            event_box.add (cover);

            name_entry = new Gtk.Entry ();
            name_entry.get_style_context ().add_class("h3");
            name_entry.text = artist.name;

            grid.attach (event_box, 0, 0, 2, 1);
            grid.attach (name_entry, 0, 1, 2, 1);

            content.pack_start (grid, false, false, 0);

            var save_button = this.add_button (_("Save"), Gtk.ResponseType.ACCEPT) as Gtk.Button;
            save_button.get_style_context ().add_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            this.show_all ();
        }

        private void save () {
            var new_name = name_entry.text.strip ();
           /* var album_exists = album.artist.get_album_by_title (new_title);
            if (album_exists == null || album_exists.ID == album.ID) {
                album.title = new_title;
                album.year = new_year;
                db_manager.update_album (album);
                if (cover_changed) {
                    album.set_new_cover (cover.pixbuf, 256);
                    if (settings.save_custom_covers) {
                        album.set_custom_cover_file (new_cover_path);
                    }
                }
            } else {
                GLib.List<Objects.Album> albums = new GLib.List<Objects.Album> ();
                albums.append (album);
                library_manager.merge_albums (albums, album_exists);
                if (cover_changed) {
                    album_exists.set_new_cover (cover.pixbuf, 256);
                    if (settings.save_custom_covers) {
                        album_exists.set_custom_cover_file (new_cover_path);
                    }
                }
            }*/
            this.destroy ();
        }
    }
}
