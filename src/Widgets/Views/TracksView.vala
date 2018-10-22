/*-
 * Copyright (c) 2018-2018 Artem Anufrij <artem.anufrij@live.de>
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
    public class TracksView : Gtk.Grid {
        Services.LibraryManager library_manager;
        PlayMyMusic.Settings settings;
        Services.Player player;

        Gtk.TreeView view;
        Gtk.TreeModelFilter modelfilter;
        Gtk.TreeModelSort modelsort;
        Gtk.ListStore listmodel;
        Gtk.Image background;
        Gtk.Image album;
        Gtk.Grid header;
        Granite.Widgets.AlertView alert_view;
        Gtk.Menu menu = null;
        Gtk.Menu playlists;

        Gtk.Label title_name;
        Gtk.Label album_title;

        Objects.Track current_track;

        bool only_mark = false;

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

        GLib.List<int> shuffle_index = null;

        enum columns { OBJECT, NR, TRACK, ALBUM, ARTIST, DURATION, DURATION_SORT }

        int header_height = 256;

        construct {
            settings = Settings.get_default ();
            library_manager = Services.LibraryManager.instance;
            library_manager.added_new_track.connect (
                (track) => {
                    Idle.add (
                        () => {
                            add_track (track);
                            return false;
                        });
                });

            player = Services.Player.instance;
            player.state_changed.connect (
                (state) => {
                    if (state == Gst.State.PLAYING) {
                        mark_playing_track (player.current_track);
                    }
                });
            player.next_track_request.connect (
                () => {
                    Objects.Track next_track = null;
                    if (settings.shuffle_mode) {
                        next_track = get_shuffle_track ();
                    } else {
                        next_track = get_next_track ();
                    }

                    if (next_track == null && settings.repeat_mode != RepeatMode.OFF) {
                        if (settings.shuffle_mode) {
                            next_track = get_shuffle_track ();
                        } else {
                            next_track = get_first_track ();
                        }
                    }
                    return next_track;
                });
            player.prev_track_request.connect (
                () => {
                    return get_prev_track ();
                });
        }

        public TracksView () {
            listmodel = new Gtk.ListStore (
                7,
                typeof (Objects.Track),
                typeof (int),
                typeof (string),
                typeof (string),
                typeof (string),
                typeof (string),
                typeof (uint64));

            shuffle_index = new GLib.List<int> ();

            build_ui ();
        }

        private void build_ui () {
            header = new Gtk.Grid ();
            header.row_spacing = 6;
            header.valign = Gtk.Align.CENTER;

            background = new Gtk.Image ();
            background.hexpand = true;
            background.height_request = header_height;

            album = new Gtk.Image ();
            album.get_style_context ().add_class ("card");
            album.margin_top = 32;
            album.margin_bottom = 32;
            album.margin_start = 64;
            album.margin_end = 64;
            album.height_request = 192;
            album.width_request = 192;
            header.attach (album, 0, 0, 1, 2);

            title_name = new Gtk.Label ("");
            title_name.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);
            title_name.valign = Gtk.Align.END;
            title_name.halign = Gtk.Align.START;
            title_name.ellipsize = Pango.EllipsizeMode.END;
            header.attach (title_name, 1, 0);

            album_title = new Gtk.Label ("");
            album_title.valign = Gtk.Align.START;
            album_title.halign = Gtk.Align.START;
            album_title.ellipsize = Pango.EllipsizeMode.END;
            album_title.use_markup = true;
            header.attach (album_title, 1, 1);

            alert_view = new Granite.Widgets.AlertView (_ ("Choose a Track"), _ ("No track selected"), "view-list-symbolic");
            alert_view.vexpand = false;

            var overlay = new Gtk.Overlay ();
            overlay.height_request = header_height;
            overlay.add_overlay (background);
            overlay.add_overlay (header);
            overlay.add_overlay (alert_view);

            view = new Gtk.TreeView ();
            view.activate_on_single_click = true;

            view.row_activated.connect (
                (path, column) => {
                    show_track (get_track_by_path (path));
                });
            view.button_press_event.connect (show_context_menu);

            view.insert_column_with_attributes (-1, "object", new Gtk.CellRendererText ());

            var cell = new Gtk.CellRendererText ();
            cell.xalign = 1.0f;
            view.insert_column_with_attributes (-1, _ ("Nr"), cell, "text", columns.NR);

            cell = new Gtk.CellRendererText ();
            cell.ellipsize = Pango.EllipsizeMode.END;
            cell.ellipsize_set = true;
            cell.stretch = Pango.Stretch.ULTRA_EXPANDED;
            cell.stretch_set = true;
            view.insert_column_with_attributes (-1, _ ("Title"), cell, "text", columns.TRACK);

            cell = new Gtk.CellRendererText ();
            cell.ellipsize = Pango.EllipsizeMode.END;
            cell.ellipsize_set = true;
            cell.stretch = Pango.Stretch.EXPANDED;
            cell.stretch_set = true;
            view.insert_column_with_attributes (-1, _ ("Album"), cell, "text", columns.ALBUM);

            view.insert_column_with_attributes (-1, _ ("Artist"), new Gtk.CellRendererText (), "text", columns.ARTIST);

            cell = new Gtk.CellRendererText ();
            cell.xalign = 1.0f;
            cell.width = 64;
            view.insert_column_with_attributes (-1, _ ("Duration"), cell, "text", columns.DURATION);
            view.insert_column_with_attributes (-1, "Duration_SORT", new Gtk.CellRendererText (), "text", columns.DURATION_SORT);

            setup_columns ();

            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scroll.expand = true;
            scroll.add (view);

            this.attach (overlay, 0, 0);
            this.attach (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), 0, 1);
            this.attach (scroll, 0, 2);
        }

        public void init_end () {
            modelfilter = new Gtk.TreeModelFilter (listmodel, null);
            modelfilter.set_visible_func (tracks_filter_func);

            modelsort = new Gtk.TreeModelSort.with_model (modelfilter);
            view.set_model (modelsort);
        }

        private void setup_columns () {
            var col = view.get_column (columns.OBJECT);
            col.visible = false;

            col = view.get_column (columns.ARTIST);
            col.resizable = true;

            col = view.get_column (columns.ALBUM);
            col.resizable = true;
            col.expand = true;

            col = view.get_column (columns.TRACK);
            col.expand = true;
            col.resizable = true;

            col = view.get_column (columns.DURATION_SORT);
            col.visible = false;

            setup_column_sort ();
        }

        private void setup_column_sort () {
            view.get_column (columns.NR).sort_column_id = columns.NR;
            view.get_column (columns.TRACK).sort_column_id = columns.TRACK;
            view.get_column (columns.ALBUM).sort_column_id = columns.ALBUM;
            view.get_column (columns.ARTIST).sort_column_id = columns.ARTIST;
            view.get_column (columns.DURATION).sort_column_id = columns.DURATION_SORT;
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                if (menu == null) {
                    build_context_menu ();
                }

                // GET SELECTED TRACK
                Gtk.TreePath path = null;
                PlayMyMusic.Objects.Track ? track = null;
                int cell_x, cell_y;
                view.get_path_at_pos ((int)evt.x, (int)evt.y, out path, null, out cell_x, out cell_y);

                if (path == null) {
                    return false;
                }

                track = get_track_by_path (path);

                if (track == null) {
                    return false;
                }

                foreach (var child in playlists.get_children ()) {
                    child.destroy ();
                }
                var item = new Gtk.MenuItem.with_label (_ ("Create New Playlist"));
                item.activate.connect (
                    () => {
                        var new_playlist = library_manager.create_new_playlist ();
                        library_manager.add_track_into_playlist (new_playlist, track.ID);
                    });
                playlists.add (item);
                if (library_manager.playlists.length () > 0) {
                    playlists.add (new Gtk.SeparatorMenuItem ());
                }
                foreach (var playlist in library_manager.playlists) {
                    item = new Gtk.MenuItem.with_label (playlist.title);
                    item.activate.connect (
                        () => {
                            library_manager.add_track_into_playlist (playlist, track.ID);
                        });
                    playlists.add (item);
                }
                playlists.show_all ();

                menu.popup (null, null, null, evt.button, evt.time);
            }
            return false;
        }

        private void build_context_menu () {
            menu = new Gtk.Menu ();
            var menu_add_into_playlist = new Gtk.MenuItem.with_label (_ ("Add into Playlist"));
            menu.add (menu_add_into_playlist);

            playlists = new Gtk.Menu ();
            menu_add_into_playlist.set_submenu (playlists);

            menu.show_all ();
        }

        public void add_track (Objects.Track track) {
            Gtk.TreeIter iter;
            listmodel.append (out iter);
            listmodel.set (iter, columns.OBJECT, track, columns.NR, track.track, columns.TRACK, track.title, columns.ALBUM, track.album.title, columns.ARTIST, track.album.artist.name, columns.DURATION, Utils.get_formated_duration (track.duration), columns.DURATION_SORT, track.duration);
        }

        private void show_track (Objects.Track track) {
            if (track == current_track) {
                return;
            }
            alert_view.hide ();

            if (current_track != null) {
                if (track.album.artist.ID != current_track.album.artist.ID) {
                    clear_background ();
                }
            }
            if (current_track == null || track.album.ID != current_track.album.ID) {
                if (track.album.cover == null) {
                    album.set_from_icon_name ("audio-x-generic-symbolic", Gtk.IconSize.DIALOG);
                } else {
                    album.pixbuf = track.album.cover.scale_simple (192, 192, Gdk.InterpType.BILINEAR);
                }
            }
            current_track = track;

            title_name.label = track.title;
            album_title.label = _ ("<b>%s</b> by <b>%s</b>").printf (track.album.title.replace ("&", "&amp;"), track.album.artist.name.replace ("&", "&amp;"));

            current_track.album.cover_changed.connect (change_cover);

            load_background ();
            play_track (track);
        }

        private void play_track (Objects.Track track) {
            if (!only_mark) {
                library_manager.play_track (track, Services.PlayMode.TRACKS);
            }
        }

        public void mark_playing_track (Objects.Track ? track) {
            view.get_selection ().unselect_all ();
            if (track == null || track == current_track) {
                return;
            }

            var i = activate_by_track (track);

            if (settings.shuffle_mode) {
                shuffle_index.append (i);
            } else if (shuffle_index.length () > 0) {
                shuffle_index = new GLib.List<int> ();
            }
        }

        public int activate_by_track (Objects.Track track) {
            int i = 0;
            if (PlayMyMusicApp.instance.mainwindow.content.visible_child_name == "tracks") {
                view.grab_focus ();
            }
            modelfilter.@foreach (
                (model, path, iter) => {
                    var item_track = get_track_by_path (path);
                    if (item_track.ID == track.ID) {
                        only_mark = true;
                        view.get_selection ().select_path (path);
                        view.scroll_to_cell (path, null, false, 0, 0);
                        view.set_cursor (path, null, false);
                        show_track (track);
                        only_mark = false;
                        return true;
                    }
                    i++;
                    return false;
                });
            return i;
        }

        private void change_cover () {
            album.pixbuf = current_track.album.cover.scale_simple (192, 192, Gdk.InterpType.BILINEAR);
        }

        public void load_background () {
            int width = header.get_allocated_width ();
            int height = background.height_request;
            if (current_track == null || current_track.album.artist.background_path == null || current_track.album.artist.background == null || (background.pixbuf != null && background.pixbuf.width == width && background.pixbuf.height == height)) {
                return;
            }
            if (height < width) {
                var pix = current_track.album.artist.background.scale_simple (width, width, Gdk.InterpType.BILINEAR);
                background.pixbuf = new Gdk.Pixbuf.subpixbuf (pix, 0, (int)(pix.height - height) / 2, width, height);
            } else {
                var pix = current_track.album.artist.background.scale_simple (height, height, Gdk.InterpType.BILINEAR);
                background.pixbuf = new Gdk.Pixbuf.subpixbuf (pix, (int)(pix.width - width) / 2, 0, width, height);
            }

            title_name.get_style_context ().add_class ("artist-title");
            album_title.get_style_context ().add_class ("artist-sub-title");
        }

        private void clear_background () {
            background.pixbuf = null;
            title_name.get_style_context ().remove_class ("artist-title");
            album_title.get_style_context ().remove_class ("artist-sub-title");
        }

        public void reset () {
            listmodel.clear ();
            clear_background ();
            alert_view.show ();
        }

        private Objects.Track ? get_track_by_path (Gtk.TreePath path) {
            Value val;
            Gtk.TreeIter iter;
            modelsort.get_iter (out iter, path);
            modelsort.get_value (iter, 0, out val);
            return val.get_object () as Objects.Track;
        }

        public Objects.Track ? get_next_track () {
            shuffle_index = null;

            Objects.Track ? return_value = null;

            modelsort.@foreach (
                (model, path, iter) => {
                    var item_track = get_track_by_path (path);
                    if (item_track.ID == current_track.ID) {
                        Gtk.TreeIter next_iter = iter;
                        if (modelsort.iter_next (ref next_iter)) {
                            Value val;
                            modelsort.get_value (next_iter, 0, out val);
                            return_value = val.get_object () as Objects.Track;
                        }
                        return true;
                    }
                    return false;
                });

            return return_value;
        }

        public Objects.Track ? get_first_track () {
            Objects.Track ? return_value = null;

            Gtk.TreeIter next_iter;
            if (modelsort.get_iter_first (out next_iter)) {
                Value val;
                modelsort.get_value (next_iter, 0, out val);
                return_value = val.get_object () as Objects.Track;
            }

            return return_value;
        }

        public Objects.Track ? get_shuffle_track () {
            var tracks_count = modelsort.iter_n_children (null);

            if (shuffle_index.length () >= tracks_count) {
                shuffle_index = new GLib.List<int> ();
                return null;
            }

            int r = GLib.Random.int_range (0, tracks_count);
            while (shuffle_index.index (r) != -1) {
                r = GLib.Random.int_range (0, tracks_count);
            }

            Objects.Track ? return_value = null;

            int i = 0;
            modelsort.@foreach (
                (model, path, iter) => {
                    var item_track = get_track_by_path (path);
                    if (i == r) {
                        return_value = item_track;
                        return true;
                    }
                    i++;
                    return false;
                });

            return return_value;
        }

        public Objects.Track ? get_prev_track () {
            Objects.Track ? return_value = null;

            modelsort.@foreach (
                (model, path, iter) => {
                    var item_track = get_track_by_path (path);
                    if (item_track.ID == current_track.ID) {
                        Gtk.TreeIter prev_iter = iter;
                        if (modelsort.iter_previous (ref prev_iter)) {
                            Value val;
                            modelsort.get_value (prev_iter, 0, out val);
                            return_value = val.get_object () as Objects.Track;
                        }
                        return true;
                    }
                    return false;
                });

            return return_value;
        }

        private bool tracks_filter_func (Gtk.TreeModel model, Gtk.TreeIter iter) {
            if (filter.strip ().length == 0) {
                return true;
            }

            var filter_elements = filter.strip ().down ();

            Value val;
            listmodel.get_value (iter, 0, out val);
            var track = val as Objects.Track;
            if (!track.title.down ().contains (filter_elements) && !track.album.title.down ().contains (filter_elements) && !track.album.artist.name.down ().contains (filter_elements)) {
                return false;
            }
            return true;
        }

        private void do_filter () {
            modelfilter.refilter ();
            shuffle_index = null;
        }
    }
}
