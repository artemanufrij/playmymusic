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
    public class AlbumEditor : Gtk.Dialog {
        PlayMyMusic.Services.LibraryManager library_manager;
        PlayMyMusic.Services.DataBaseManager db_manager;
        Objects.Album album;

        Gtk.Entry title_entry;
        Gtk.Entry year_entry;

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
            db_manager = PlayMyMusic.Services.DataBaseManager.instance;
        }

        public AlbumEditor (Gtk.Window parent, Objects.Album album) {
            Object (
                transient_for: parent
            );
            this.album = album;
            build_ui ();

            this.response.connect ((source, response_id) => {
                switch (response_id) {
                    case Gtk.ResponseType.ACCEPT:
                        var new_title = title_entry.text.strip ();
                        var new_year = int.parse (year_entry.text);
                        var album_exists = album.artist.get_album_by_title (new_title);
                        if (album_exists == null || album_exists.ID == album.ID) {
                            album.title = new_title;
                            album.year = new_year;
                            db_manager.update_album (album);
                        } else {
                            GLib.List<Objects.Album> albums = new GLib.List<Objects.Album> ();
                            albums.append (album);
                            library_manager.merge_albums (albums, album_exists);
                        }
                        destroy ();
                    break;
                }
            });
        }

        private void build_ui () {
            this.resizable = false;
            var content = get_content_area () as Gtk.Box;

            var grid = new Gtk.Grid ();
            grid.column_spacing = 12;
            grid.row_spacing = 12;
            grid.margin = 12;

            var cover = new Gtk.Image ();
            if (album.cover == null) {
                cover.set_from_icon_name ("audio-x-generic-symbolic", Gtk.IconSize.DIALOG);
                cover.height_request = 256;
                cover.width_request = 256;
            } else {
                cover.pixbuf = album.cover;
            }

            title_entry = new Gtk.Entry ();
            title_entry.text = album.title;

            var year_label = new Gtk.Label (_("Year"));
            year_label.halign = Gtk.Align.END;
            year_entry = new Gtk.Entry ();
            year_entry.text = album.year.to_string ();

            grid.attach (cover, 0, 0, 2, 1);
            grid.attach (title_entry, 0, 1, 2, 1);
            grid.attach (year_label, 0, 2);
            grid.attach (year_entry, 1, 2);
            content.pack_start (grid, false, false, 0);

            var save_button = this.add_button (_("Save"), Gtk.ResponseType.ACCEPT) as Gtk.Button;
            save_button.get_style_context ().add_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            this.show_all ();
        }
    }
}
