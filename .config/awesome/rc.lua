-- vim:set sw=4 et path=/usr/share/awesome/lib:

require("awful")
require("awful.autofocus")
require("awful.rules")
require("beautiful")
require("naughty")
-- require("revelation")
require("obvious.loadavg")
require("obvious.temp_info")
require("obvious.battery")
vicious = require("vicious")

-- Debugging {{{

-- Where does stdout go?
function print (...)
    local output = ""
    for i, v in ipairs(arg) do
        output = output .. tostring(v) .. "\t"
    end
    io.stderr:write(output:sub(1,-2), "\n")
end

function inspect (object)
    if type(object) == 'string' then
        return string.format("%q", object)
    elseif type(object) == 'table' then
        local output = "{"
        for k, v in pairs(object) do
            output = output .. tostring(k) .. '=' .. inspect(v) .. ', '
        end
        return output:sub(1, -3) .. "}"
    else
        return tostring(object)
    end
end

function p (object)
    print(inspect(object))
end

-- }}}

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.add_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         timeout = 20,
                         text = err })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, and wallpapers
beautiful.init(awful.util.getdir("config") .. "/theme.lua")

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
layouts =
{
    -- awful.layout.suit.floating,
    awful.layout.suit.tile,
    -- awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    -- awful.layout.suit.tile.top,
    awful.layout.suit.fair,
    -- awful.layout.suit.fair.horizontal,
    -- awful.layout.suit.spiral,
    -- awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    -- awful.layout.suit.max.fullscreen
    -- awful.layout.suit.magnifier
}
-- }}}

-- Run or Raise {{{

--- Spawns cmd if no client can be found matching properties
-- If such a client can be found, pop to first tag where it is visible, and give it focus
-- @param cmd the command to execute
-- @param properties a table of properties to match against clients.  Possible entries: any properties of the client object
function run_or_raise(cmd, properties)
   local clients = client.get()
   local focused = awful.client.next(0)
   local findex = 0
   local matched_clients = {}
   local n = 0
   for i, c in pairs(clients) do
      --make an array of matched clients
      if client_match(properties, c) then
         n = n + 1
         matched_clients[n] = c
         if c == focused then
            findex = n
         end
      end
   end
   if n > 0 then
      local c = matched_clients[1]
      -- if the focused window matched switch focus to next in list
      if 0 < findex and findex < n then
         c = matched_clients[findex+1]
      end
      local ctags = c:tags()
      if table.getn(ctags) == 0 then
         -- ctags is empty, show client on current tag
         local curtag = awful.tag.selected()
         awful.client.movetotag(curtag, c)
      else
         -- Otherwise, pop to first tag client is visible on
         awful.tag.viewonly(ctags[1])
      end
      -- And then focus the client
      client.focus = c
      c:raise()
      return c
   end
   if cmd then
       awful.util.spawn(cmd)
   end
end

-- Returns true if all pairs in table1 are present in table2
function client_match (conditions, client)
   for k, v in pairs(conditions) do
      if client[k] == v or tostring(client[k]):find(v) then
         return true
      end
   end
   return false
end

function browser ()
    return run_or_raise('tpope browse', {class = "Uzbl-tabbed", role = 'browser'})
end

-- }}}

-- Editor {{{

editor_cmd = 'tpope edit'

function complete_file (text, cur_pos, ncomp)
    text, cur_pos, ncomp = awful.completion.shell("gvim " .. text, 5 + cur_pos, ncomp)
    return text:sub(6), cur_pos - 5, ncomp
end

function prompt_file (callback)
    awful.prompt.run({prompt = "File: "},
    mypromptbox[mouse.screen].widget,
    callback,
    complete_file
    )
end

function edit (file)
    awful.util.spawn(editor_cmd .. ' "' .. file .. '"')
    run_or_raise(nil, { class = '[Vv]im$' })
end

-- }}}

-- Terminal {{{

terminal = "x-terminal-emulator"
hostname = awful.util.pread('tpope host name'):sub(1, -2)

function host_cursor_rgb (host)
    return awful.util.pread("tpope host light " .. host):sub(1, -2)
end

function raise_host (host)
    run_or_raise(nil, {instance = '@' .. host})
end

function screen_host (host)
    local cmd = terminal .. ' -T @' .. host .. ' -name @' .. host ..
    " -cr  '" .. host_cursor_rgb(host) ..
    -- "' -fade 10 -fadecolor '" .. host_cursor_rgb(host) ..
    "' -e "
    if host:find(' ') then
        awful.util.spawn('ssh -X ' .. host)
    else
        if host == 'localhost' then
            cmd = cmd .. 'tpope host screen -dRR'
        else
            cmd = cmd .. 'tpope host screen -dRR ' .. host
        end
        print(cmd)
        run_or_raise(cmd, {icon_name = '^@' .. host})
    end
end

function shell_host (arg)
    local host = arg:match('%S+')
    local cmd = arg:match(' %S+')
    if cmd then
        cmd = cmd:sub(2)
    else
        cmd = 'shell'
    end
    local exec = ''
    if host ~= 'localhost' then
        exec = ' -e ssh ' .. arg:gsub(' ', ' -t ', 1)
    elseif arg:find(' ') then
        exec = ' -e' .. arg:match(' .*')
    end
    local cmd = terminal .. ' -T ' .. cmd .. '@' .. host .. ' -name ' .. cmd .. '@' .. host ..
    " -cr  '" .. host_cursor_rgb(host) ..
    -- "' -fade 10 -fadecolor  '" .. host_cursor_rgb(host) ..
    "'" .. exec
    print(cmd)
    awful.util.spawn(cmd)
end

function pick_host(callback)
  keygrabber.run(
  function(modifier, key, event)
      if event ~= "press" then return true end
      local mod4
      for k, v in ipairs(modifier) do
          if v == "Mod4" then mod4 = true end
      end
      keygrabber.stop()
      if key:find('^%u$') or mod4 then
          host = awful.util.pread("tpope host name " .. key:upper()):sub(1, -2)
          callback(host)
      else
          prompt_host({text = key:match('^.$')}, callback)
      end
      return true
  end)
end

function prompt_host(options, callback)
    options.prompt = "host: "
    awful.prompt.run(options,
    mypromptbox[mouse.screen].widget,
    callback,
    function(t, c, n)
        if(t:len() == 1) then
            local host = awful.util.pread("tpope host name " .. t):sub(1, -2)
            if host ~= "localhost" then
                return host, host:len() + 1
            end
        end
        hosts = {}
        local i = io.popen("tpope host list")
        for host in i:lines() do
            table.insert(hosts, host)
        end
        i:close()
        return awful.completion.generic(t, c, n, hosts)
    end
    )
end


function chat()
    run_or_raise(terminal .. ' -name Chat -T Chat -e tpope chat', { instance = 'Chat' })
end

-- }}}

-- {{{ Tags
-- Define a tag table which hold all screen tags.
tags = {}
for s = 1, screen.count() do
    -- Each screen has its own tag table.
    tags[s] = awful.tag({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, s, layouts[1])
end
awful.tag.setmwfact(0.5806)

-- }}}

-- {{{ Menu
function keymap()
    os.execute('setxkbmap -option ctrl:nocaps us')
end

-- Create a laucher widget and a main menu
exitmenu = {
   { "&Restart", awful.util.restart },
   { "&Quit", awesome.quit },
   { "Start &Gnome", function() awesome.exec("gnome-session") end },
   { "Start &KDE", function() awesome.exec("startkde") end },
   { "Start &Fvwm2", function() awesome.exec("fvwm2") end },
}

-- Load Debian menu entries
require("debian.menu")

mymainmenu = awful.menu({ items = {
    { "&Terminal", function () shell_host('localhost') end},
    { "&Browser", browser },
    { "&Debian", debian.menu.Debian_menu.Debian },
    { "E&xit", exitmenu },
}})

menu_launcher = awful.widget.launcher({ image = image(beautiful.awesome_icon),
                                     menu = mymainmenu})
-- }}}

-- {{{ Wibox
-- Create a textclock widget
mytextclock = awful.widget.textclock({ align = "right" })

-- Create a systray
mysystray = widget({ type = "systray" })

-- Create a wibox for each screen and add it
mywibox = {}
mypromptbox = {}
mylayoutbox = {}
mytaglist = {}
mytaglist.buttons = awful.util.table.join(
                    awful.button({ }, 1, awful.tag.viewonly),
                    awful.button({ modkey }, 1, awful.client.movetotag),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, awful.client.toggletag),
                    awful.button({ }, 4, awful.tag.viewnext),
                    awful.button({ }, 5, awful.tag.viewprev)
                    )
mytasklist = {}
mytasklist.buttons = awful.util.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  if not c:isvisible() then
                                                      awful.tag.viewonly(c:tags()[1])
                                                  end
                                                  -- This will also un-minimize
                                                  -- the client, if needed
                                                  client.focus = c
                                                  c:raise()
                                              end
                                          end),
                     awful.button({ }, 3, function ()
                                              if instance then
                                                  instance:hide()
                                                  instance = nil
                                              else
                                                  instance = awful.menu.clients({ width=250 })
                                              end
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                              if client.focus then client.focus:raise() end
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                              if client.focus then client.focus:raise() end
                                          end))

for s = 1, screen.count() do
    -- Create a promptbox for each screen
    mypromptbox[s] = awful.widget.prompt({ layout = awful.widget.layout.horizontal.leftright })
    -- Create an imagebox widget which will contains an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    mylayoutbox[s] = awful.widget.layoutbox(s)
    mylayoutbox[s]:buttons(awful.util.table.join(
                           awful.button({ }, 1, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(layouts, -1) end),
                           awful.button({ }, 4, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)))
    -- Create a taglist widget
    mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.label.all, mytaglist.buttons)

    -- Create a tasklist widget
    mytasklist[s] = awful.widget.tasklist(function(c)
                                              return awful.widget.tasklist.label.currenttags(c, s)
                                          end, mytasklist.buttons)

    -- Create the wibox
    mywibox[s] = awful.wibox({ position = "top", screen = s, height = 16 })
    -- Add widgets to the wibox - order matters
    mywibox[s].widgets = {
        {
            menu_launcher,
            mytaglist[s],
            mypromptbox[s],
            layout = awful.widget.layout.horizontal.leftright
        },
        mylayoutbox[s],
        mytextclock,
        obvious.battery(),
        -- obvious.loadavg(),
        obvious.temp_info({margin = { left = 5, right = 5 }}),
        s == 1 and mysystray or nil,
        mytasklist[s],
        layout = awful.widget.layout.horizontal.rightleft
    }
end
-- }}}

-- {{{ Mouse bindings
root.buttons(awful.util.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings

function executor (cmd)
    return function () os.execute(cmd) end
end

globalkeys = awful.util.table.join(
    awful.key({modkey, "Mod1"   }, "a", executor('import -window root $HOME/Pictures/root-`date +%Y-%m-%d_%H-%M-%S`.png')),
    awful.key({modkey, "Shift"  }, "a", executor('import $HOME/Pictures/selection-`date +%Y-%m-%d_%H-%M-%S`.png')),
    awful.key({}, "XF86AudioLowerVolume", executor("tpope media softer")),
    awful.key({}, "XF86AudioRaiseVolume", executor("tpope media louder")),
    awful.key({ modkey, }, "bracketleft", executor("tpope media softer")),
    awful.key({ modkey, }, "bracketright", executor("tpope media louder")),
    awful.key({ modkey, }, "backslash", executor("tpope media pause")),
    awful.key({ modkey, }, "equal", function() client.focus:raise() end),
    awful.key({ modkey, }, "minus", function() client.focus:lower() end),
    awful.key({ modkey, "Mod1" }, "bracketleft", executor("tpope media previous")),
    awful.key({ modkey, "Mod1" }, "bracketright", executor("tpope media next")),
    awful.key({ modkey, "Mod1" }, "backslash", executor("tpope media toggle")),
    -- awful.key({ modkey,           }, "Left",   awful.tag.viewprev       ),
    -- awful.key({ modkey,           }, "Right",  awful.tag.viewnext       ),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore),

    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey,           }, "w", function () mymainmenu:show({keygrabber=true, coords={x=0, y=16}}) end),
    awful.key({ modkey,           }, "a", function () mymainmenu:show({keygrabber=true, coords={x=0, y=16}}) end),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end),

    -- Standard program
    awful.key({ modkey, "Control" }, "r", awesome.restart),
    awful.key({ modkey, "Mod1"    }, "r", keymap),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)    end),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)    end),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1)      end),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1)      end),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1)         end),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1)         end),
    awful.key({ modkey,           }, "space", function () awful.layout.inc(layouts,  1) end),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end),

    awful.key({ modkey, "Control" }, "n", awful.client.restore),

    -- Prompt
    awful.key({ modkey },            "r", function () mypromptbox[mouse.screen]:run() end),
    awful.key({ modkey, "Mod1" },    "r", function () awful.prompt.run(
        { prompt = "Run in terminal: " },
        mypromptbox[mouse.screen].widget,
        function (cmd) shell_host('localhost ' .. cmd) end,
        awful.completion.shell
    ) end),
    awful.key({ modkey, "Mod1"    }, "e", function () prompt_file(edit) end),
    awful.key({ modkey,           }, "e", function () prompt_file(edit) end),
    awful.key({ modkey            }, "semicolon", function () run_or_raise(nil, { class = '[Vv]im$' }) end),
    -- awful.key({ modkey            }, "e", function () run_or_raise('gvim', { class = '[Vv]im$' }) end),
    awful.key({ modkey            }, "c", chat),
    awful.key({ modkey            }, "z", function () raise_host('localhost') end),
    awful.key({ modkey, "Mod1"    }, "z", function () screen_host('localhost') end),
    awful.key({ modkey, "Control" }, "z", function () shell_host('localhost') end),
    awful.key({ modkey, "Mod1"    }, "s", function () pick_host(screen_host) end),
    awful.key({ modkey, "Control" }, "s", function () pick_host(shell_host) end),
    awful.key({ modkey            }, "s", function () pick_host(raise_host) end),
    awful.key({ modkey }, "x", function () local c = browser() if c then c:swap(awful.client.getmaster()) end end),

    awful.key({ modkey            }, "p",
              function ()
                  awful.prompt.run({ prompt = "Run Lua code: " },
                  mypromptbox[mouse.screen].widget,
                  awful.util.eval, nil,
                  awful.util.getdir("cache") .. "/history_eval")
              end)
)

clientkeys = awful.util.table.join(
    awful.key({ modkey }, "Next",  function () awful.client.moveresize( 20,  20, -40, -40) end),
    awful.key({ modkey }, "Prior", function () awful.client.moveresize(-20, -20,  40,  40) end),
    awful.key({ modkey }, "Down",  function () awful.client.moveresize(  0,  20,   0,   0) end),
    awful.key({ modkey }, "Up",    function () awful.client.moveresize(  0, -20,   0,   0) end),
    awful.key({ modkey }, "Left",  function () awful.client.moveresize(-20,   0,   0,   0) end),
    awful.key({ modkey }, "Right", function () awful.client.moveresize( 20,   0,   0,   0) end),
    awful.key({modkey, "Control"  }, "a", function (c)
        os.execute('import -window ' .. c.window .. ' $HOME/Pictures/' .. (c.title or "unnamed") .. ' -`date +%Y-%m-%d_%H-%M-%S`.png') end),
    awful.key({ modkey,           }, "f",      function (c) c.fullscreen = not c.fullscreen  end),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end),
    awful.key({ modkey,           }, "Return", function (c) c:swap(awful.client.getmaster()) end),
    awful.key({ modkey,           }, "o",      awful.client.movetoscreen                        ),
    awful.key({ modkey, "Shift"   }, "r",      function (c) c:redraw()                       end),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end),
    awful.key({ modkey,           }, "i",      function (c) awful.util.spawn("sh -c '(xwininfo -id " .. c.window .. "; xprop -id " .. c.window .. ")|tail -n +2|xmessage -title " .. c.window .. " -file -'") end),
    awful.key({ modkey, "Mod1"    }, "i",      function (c) awful.util.spawn("sh -c 'xwininfo -id " .. c.window .. "|gxmessage -title xwininfo -file -'") end),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c.maximized_vertical   = not c.maximized_vertical
        end)
)

-- Compute the maximum number of digit we need, limited to 9
keynumber = 0
for s = 1, screen.count() do
   keynumber = math.min(9, math.max(#tags[s], keynumber));
end

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, keynumber do
    globalkeys = awful.util.table.join(globalkeys,
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = mouse.screen
                        if tags[screen][i] then
                            awful.tag.viewonly(tags[screen][i])
                        end
                  end),
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = mouse.screen
                      if tags[screen][i] then
                          awful.tag.viewtoggle(tags[screen][i])
                      end
                  end),
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus and tags[client.focus.screen][i] then
                          awful.client.movetotag(tags[client.focus.screen][i])
                      end
                  end),
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus and tags[client.focus.screen][i] then
                          awful.client.toggletag(tags[client.focus.screen][i])
                      end
                  end))
end

clientbuttons = awful.util.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize))

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = true,
                     keys = clientkeys,
                     buttons = clientbuttons } },
    { rule = { class = "MPlayer" },
      properties = { floating = true } },
    { rule = { class = "pinentry" },
      properties = { floating = true } },
    -- { rule = { class = "gimp" },
    --   properties = { floating = true, tag = tags[1][6] } },
    -- Set Firefox to always map on tags number 2 of screen 1.
    -- { rule = { class = "Firefox" },
    --   properties = { tag = tags[1][2] } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.add_signal("manage", function (c, startup)
    if c.instance and c.instance:find('@[%w-]+%*?$') then
        local host, color, dark
        host = c.instance:match('@[%w-]+'):sub(2)
        if host == 'localhost' then host = hostname end
        color = awful.util.pread('tpope host color ' .. host):sub(1, -2)
        dark = awful.util.pread('tpope host dark ' .. host):sub(1, -2)
        if c.instance:find('^@') then
            c.icon = image(os.getenv('HOME') .. '/.pixmaps/mini/terminal/left-' .. color .. '.xpm')
        else
            c.icon = image(os.getenv('HOME') .. '/.pixmaps/mini/terminal/right-' .. color .. '.xpm')
        end
        awful.titlebar.add(c, { modkey = modkey, height = 16, fg_focus = dark })
    else
        awful.titlebar.add(c, { modkey = modkey, height = 16 })
    end

    -- Enable sloppy focus
    c:add_signal("mouse::enter", function(c)
        if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
            and awful.client.focus.filter(c) then
            client.focus = c
        end
    end)

    if not startup then
        -- Set the windows at the slave,
        -- i.e. put it at the end of others instead of setting it master.
        -- awful.client.setslave(c)

        -- Put windows in a smart way, only if they does not set an initial position.
        if not c.size_hints.user_position and not c.size_hints.program_position then
            awful.placement.no_overlap(c)
            awful.placement.no_offscreen(c)
        end
    end
end)

client.add_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.add_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}
