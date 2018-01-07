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

    public enum TrackStyle { ALBUM, ARTIST, PLAYLIST, AUDIO_CD }

    public class Track : Gtk.ListBoxRow {
        PlayMyMusic.Services.LibraryManager library_manager;

        public PlayMyMusic.Objects.Track track { get; private set; }
        public string title { get { return track.title; } }
        public int track_number { get { return track.track; } }
        public int disc_number { get { return track.disc; } }

        Gtk.Box content;
        Gtk.Image cover;
        Gtk.Image warning;
        Gtk.Menu menu;
        Gtk.Menu playlists;
        Gtk.Menu send_to;
        Gtk.MenuItem menu_send_to;
        Gtk.Label track_title;

        TrackStyle track_style;

        construct {
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
        }

        public Track (PlayMyMusic.Objects.Track track, TrackStyle track_style = TrackStyle.ALBUM) {
            this.track_style = track_style;
            this.track = track;
            this.track.removed.connect (() => {
                Idle.add (() => {
                    this.destroy ();
                    return false;
                });
            });
            this.track.path_not_found.connect (() => {
                if (warning == null) {
                    warning = new Gtk.Image.from_icon_name ("process-error-symbolic", Gtk.IconSize.MENU);
                    warning.tooltip_text = _("File couldn't be found\n%s").printf (track.uri);
                    warning.halign = Gtk.Align.END;
                    content.pack_end (warning);
                    warning.show_all ();
                }
            });
            this.track.notify ["title"].connect (() => {
                track_title.label = track.title;
            });

            build_ui ();
        }

        public void build_ui () {
            this.tooltip_text = this.track.title;

            var event_box = new Gtk.EventBox ();

            content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            if (this.track_style == TrackStyle.PLAYLIST || this.track_style == TrackStyle.ARTIST || this.track_style == TrackStyle.AUDIO_CD) {
                content.spacing = 12;
                content.margin = 12;
            } else {
                content.margin = 6;
                content.spacing = 6;
            }

            content.margin_top = content.margin_bottom = 6;
            content.halign = Gtk.Align.FILL;
            event_box.add (content);

            if (this.track_style != TrackStyle.AUDIO_CD) {
                if (this.track_style == TrackStyle.PLAYLIST) {
                    const Gtk.TargetEntry[] targetentries = {{ "STRING", 0, 0 }};

                    Gtk.drag_source_set (event_box, Gdk.ModifierType.BUTTON1_MASK, targetentries, Gdk.DragAction.MOVE);
                    event_box.drag_data_get.connect (on_drag_data_get);
                    event_box.drag_begin.connect (on_drag_begin);

                    Gtk.drag_dest_set (event_box, Gtk.DestDefaults.ALL, targetentries, Gdk.DragAction.MOVE);
                    event_box.drag_leave.connect ((context, time) => {
                        content.margin_top = 6;
                        this.get_style_context ().remove_class ("track-drag-begin");
                    });
                    event_box.drag_motion.connect ((context, x, y, time) => {
                        content.margin_top = 5;
                        Gtk.drag_unhighlight (event_box);
                        this.get_style_context ().add_class ("track-drag-begin");
                        return false;
                    });
                    event_box.drag_data_received.connect ((drag_context, x, y, data, info, time) => {
                        on_drag_data_received (data.get_text ());
                    });
                }
                event_box.button_press_event.connect (show_context_menu);

                menu = new Gtk.Menu ();
                var menu_add_into_playlist = new Gtk.MenuItem.with_label (_("Add into Playlist"));
                menu.add (menu_add_into_playlist);

                if (track.playlist != null) {
                    var menu_remove_from_playlist = new Gtk.MenuItem.with_label (_("Remove from Playlist"));
                    menu_remove_from_playlist.activate.connect (() => {
                        library_manager.remove_track_from_playlist (track);
                    });
                    menu.add (menu_remove_from_playlist);
                }

                playlists = new Gtk.Menu ();
                menu_add_into_playlist.set_submenu (playlists);

                menu_send_to = new Gtk.MenuItem.with_label (_("Send to"));
                menu.add (menu_send_to);
                send_to = new Gtk.Menu ();
                menu_send_to.set_submenu (send_to);

                menu.show_all ();
            }

            if (this.track_style == TrackStyle.PLAYLIST || this.track_style == TrackStyle.ARTIST) {
                cover = new Gtk.Image ();
                cover.get_style_context ().add_class ("card");
                cover.tooltip_text = this.track.album.title;
                if (this.track.album.cover == null) {
                    cover.set_from_icon_name ("audio-x-generic-symbolic", Gtk.IconSize.DND);
                } else {
                    cover.pixbuf = this.track.album.cover_32;
                }
                content.pack_start (cover, false, false, 0);
                this.track.album.cover_changed.connect (() => {
                    Idle.add (() => {
                        cover.pixbuf = this.track.album.cover_32;
                        return false;
                    });
                });
                track.album_changed.connect ((album) => {
                    cover.tooltip_text = album.title;
                });
            }

            track_title = new Gtk.Label (this.track.title);
            track_title.xalign = 0;
            track_title.ellipsize = Pango.EllipsizeMode.END;
            content.pack_start (track_title, true, true, 0);

            if (this.track.duration > 0) {
                var duration = new Gtk.Label (PlayMyMusic.Utils.get_formated_duration (this.track.duration));
                duration.halign = Gtk.Align.END;
                content.pack_end (duration, false, false, 0);
            }

            this.add (event_box);
            this.halign = Gtk.Align.FILL;
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
                    library_manager.add_track_into_playlist (new_playlist, track.ID);
                });
                playlists.add (item);
                if (library_manager.playlists.length () > 0) {
                    playlists.add (new Gtk.SeparatorMenuItem ());
                }
                foreach (var playlist in library_manager.playlists) {
                    item = new Gtk.MenuItem.with_label (playlist.title);
                    item.activate.connect (() => {
                        library_manager.add_track_into_playlist (playlist, track.ID);
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
                            current_mobile_phone.add_track (track, music_folder);
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
            } else if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 1) {
                this.activate ();
                return true;
            }
            return false;
        }

        private void on_drag_data_get (Gdk.DragContext context, Gtk.SelectionData selection_data, uint target_type, uint time) {
            selection_data.set_text ("Playlist:%d; Track:%d".printf (this.track.playlist.ID, this.track.ID), -1);
        }

        private void on_drag_begin (Gdk.DragContext context) {
            if (this.track.album.cover_32 != null) {
                var surface = new Granite.Drawing.BufferSurface (32, 32);
                Gdk.cairo_set_source_pixbuf (surface.context, this.track.album.cover_32, 0, 0);
                surface.context.paint ();
                Gtk.drag_set_icon_surface (context, surface.surface);
            }
        }

        private void on_drag_data_received (string received) {
            Regex reg_playlist_id;
            Regex reg_track_id;
            try {
                reg_playlist_id = new Regex ("(?<=Playlist:)\\d*");
                reg_track_id = new Regex ("(?<=Track:)\\d*");
            } catch (Error err) {
                return;
            }

            int source_playlist_id = track.playlist.ID;
            int source_track_id = track.ID;

            MatchInfo match;

            if (reg_playlist_id.match (received, 0, out match)){
                source_playlist_id = int.parse (match.fetch (0));
            }

            if (reg_track_id.match (received, 0, out match)) {
                source_track_id = int.parse (match.fetch (0));
            }

            if (source_playlist_id == track.playlist.ID) {
                var source_track = track.playlist.get_track_by_id (source_track_id);
                if (source_track != null) {
                    if (source_track.track != track.track && source_track.track != track.track - 1) {
                        library_manager.resort_track_in_playlist (track.playlist, source_track, track.track);
                    }
                }
            } else {
                var source_playlist = library_manager.db_manager.get_playlist_by_id (source_playlist_id);
                if (source_playlist != null) {
                    var source_track = source_playlist.get_track_by_id (source_track_id);
                    if (source_track != null) {
                        library_manager.add_track_into_playlist (track.playlist, source_track.ID);
                        library_manager.remove_track_from_playlist (source_track);
                        source_track = track.playlist.get_track_by_id (source_track_id);
                        library_manager.resort_track_in_playlist (track.playlist, source_track, track.track);
                    }
                }
            }
        }
    }
}
