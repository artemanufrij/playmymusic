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
    public class PlaylistsView : Gtk.Grid {
        PlayMyMusic.Services.LibraryManager library_manager;
        PlayMyMusic.Settings settings;

        private string _filter = "";
        public string filter {
            get {
                return _filter;
            } set {
                if (_filter != value) {
                    _filter = value;
                    playlists.invalidate_filter ();
                }
            }
        }

        Gtk.FlowBox playlists;

        construct {
            settings = PlayMyMusic.Settings.get_default ();
            library_manager = PlayMyMusic.Services.LibraryManager.instance;
        }

        public PlaylistsView () {
            build_ui ();
        }

        private void build_ui () {
            playlists = new Gtk.FlowBox ();

            var playlists_scroll = new Gtk.ScrolledWindow (null, null);
            playlists_scroll.add (playlists);

            var action_toolbar = new Gtk.ActionBar ();

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.expand = true;
            content.pack_start (playlists_scroll, false, false, 0);
            content.pack_end (action_toolbar, false, false, 0);

            var stack = new Gtk.Stack ();
            //stack.add_named (welcome, "welcome");
            stack.add_named (content, "content");

            this.add (stack);
            this.show_all ();
        }
    }
}
