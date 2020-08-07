-- title:  Townsend
-- author: Andrew Gwozdziewycz
-- desc:   Get Work Done
-- script: lua

t = 0

-- number of tiles wifi can reach.
WIFI_RANGE = 10
WIFI_MAX_QUALITY = 3
CLOCK_TICKS_PER_HOUR = 3600
CLOCK_START_HOUR = 9
CLOCK_END_HOUR = 17
FILL_COLUMN = 28

-- (MAX_SIGNAL - signal) * JOB_LOCKOUT_TICKS
JOB_LOCKOUT_TICKS = 60

-- Vertical space for top bar.
SCREEN_YOFFSET = 10

-- TODO: This should really not be global...
ACCESS_POINTS = {
   -- desk pod
   { x = 12, y = 6, alive = true},
   { x = 27, y = 8, alive = true},

   -- podium
   { x = 15, y = 24, alive = true},

   -- south conference rooms
   { x = 30, y = 23, alive = true},

   -- copy area / east desks
   { x = 40, y = 18, alive = true},
   { x = 55, y = 18, alive = true},

   -- kitchen
   { x = 44, y = 9, alive = true},

   -- east conference room
   { x = 58, y = 7, alive = true},
}

sprites = {
   WIFI = 256,
   PLAYER = 304,
   COWORKER_1 = 305,
   COWORKER_2 = 306,
   COWORKER_3 = 307,
   COWORKER_4 = 308,

   ICON_CALENDAR_INVITE = 480,
   ICON_PERSON_GREEN = 482,
   ICON_PERSON_BLUE = 484,
   ICON_PERSON_GREYN = 486,
   ICON_BEEPER_NOTICE = 488,

   JOB_WAIT = 272,
   JOB_LOCATION = 273,
   JOB_TIME = 274,
   JOB_OK = 275,
   JOB_NOTHING = 276,
   JOB_PREREQ = 277,
   JOB_WIFI = 278,
}

flags = {
   FLOOR = 0,
   WALL = 1,
   SEAT = 2
}

Actor = {
   STANDING = 1,
   SITTING = 2,

   LEFT = {x = -1, y = 0},
   RIGHT = {x = 1, y = 0},
   UP = {x = 0, y = 1},
   DOWN = {x = 0, y = -1},
}

kitchen_boundaries = {
   min_x = 32,
   min_y = 5,
   max_x = 47,
   max_y = 16,
}

kitchen_prep_boundaries = {
   min_x = 42,
   min_y = 6,
   max_x = 47,
   max_y = 12,
}

bathroom_boundaries = {
   min_x = 43,
   min_y = 27,
   max_x = 55,
   max_y = 31,
}

town_hall_boundaries = {
   min_x = 3,
   min_y = 16,
   max_x = 20,
   max_y = 25,
}

copier_boundaries = {
   min_x = 49,
   min_y = 16,
   max_x = 50,
   max_y = 20,
}

right_conference = {
   min_x = 53,
   min_y = 8,
   max_x = 58,
   max_y = 13,
}

lower_conference_1 = {
   min_x = 22,
   min_y = 20,
   max_x = 29,
   max_y = 25,
}

lower_conference_2 = {
   min_x = 31,
   min_y = 20,
   max_x = 37,
   max_y = 25,
}

lower_conference_3 = {
   min_x = 39,
   min_y = 20,
   max_x = 43,
   max_y = 25,
}

-- fills text to cols on space boundaries.
function fill(cols, text)
   local len = string.len(text)
   local lines = {}
   local i = 1

   while i < len do
      local cur = string.sub(text, i, i+cols)
      local sor = string.len(cur)
      while sor > 0 do
         local atcursor = string.char(string.byte(cur, sor))
         print(atcursor)
         if atcursor == " " or atcursor == "\n" then
            table.insert(lines, string.sub(cur, 1, sor))
            i = i + sor
            break
         else
            sor = sor - 1
         end
      end

      if sor == 0 then
         -- save it anyway, even though it's split up
         table.insert(lines, cur)
         i = i + cols
      end
   end

   return lines
end


initial_message = {
   sprite = sprites.ICON_PERSON_GREEN,
   text = fill(FILL_COLUMN, [[
Hello! Welcome to the office! We're so happy to have you. Keep an eye out for calendar invites throughout the day, and make sure you respond to any support and Beeper Notice pages. Lunch and snacks are served throughout the day. Everything you might need to do can be achieved by hitting the A button. And, you can select the task you're working on with the B button. The icons in the top left corner of the screen give you an idea as to why you might not be able to do something. We work until 5PM. Good luck on your first day!
   ]]),
   text_i = 1,
   cb = nil,
}

-- makes a shallow copy of a table, useful for copying job constraints.
function copy(t)
   n = {}
   for k,v in pairs(t) do
      n[k] = v
   end
   return n
end

function Actor:new()
   o = {
      x = 1, -- tile coordinates
      y = 1,
   }
   setmetatable(o, self)
   self.__index = self
   return o
end

Player = Actor:new()
function Player:new(x, y)
   o = {
      x = x,
      y = y,
      direction = self.LEFT,
      state = self.STANDING,
   }
   setmetatable(o, self)
   self.__index = self
   return o
end

function Player:can_work(t)
   -- Yes, there's a misnomer here. You're not sitting at the copier,
   -- but, most work is happening when seated, so that's the work state.
   return self.state == self.SITTING
end

function Player:draw(_camera)
   spr(sprites.PLAYER, 15 * 8, (8*8) + SCREEN_YOFFSET, 0)

--   spr(sprites.PLAYER, self.x * 8, SCREEN_YOFFSET + (self.y * 8), 0)
end

function Player:can_work(t)
   return self.state == self.SITTING
end

Coworker = Actor:new()
function Coworker:new(sprite, opts)
   o = {
      sprite = sprite,
      x = opts.x,
      y = opts.y,
      direction = self.LEFT,
      paths = opts.paths,
   }
   setmetatable(o, self)
   self.__index = self
   return o
end

function Coworker:draw(camera)
   local lx, ly = camera.x - self.x, camera.y - self.y
   spr(self.sprite, (15*8) - (8*lx), (8*8) - (8*ly) + SCREEN_YOFFSET, 0)
end

HUD = {}
function HUD:new(clock, jobs, player)
   o = {
      jobs = jobs,
      clock = clock,
      player = player,
      signal = 0,
      messages = {
         initial_message,
      },
   }
   setmetatable(o, self)
   self.__index = self
   return o
end

function HUD:update_messages(ap)
   if ap and #self.messages > 0 then
      local msg = self.messages[1]
      if msg.text_i > #msg.text then
         if msg.cb then
            msg.cb()
         end
         -- reset text_i for reuse.
         msg.text_i = 1
         table.remove(self.messages, 1)
      else
         msg.text_i = msg.text_i + 3
      end
   end
end

function HUD:draw(_camera)
   -- draw the can work indicator.
   _, problem = self.jobs:work_problem(self.clock.time, self.player)
   spr(problem, 1, 1, 0)

   -- draw the jobs status.
   print(zeropad(#(self.jobs.completed)), 12, 2, 10)
   print("/", 24, 2, 11)
   local total = #(self.jobs.completed) + #(self.jobs.jobs) +
      #(self.jobs.expired)
   print(zeropad(total), 30, 2, 11)

   local perc = 0
   local desc = ""
   local current = self.jobs:current()
   if current then
      perc = current.progress / current.goal
      desc = current.desc
   end

   -- description
   print(desc, 45, 2, 11)

   -- progress bar.
   rectb(133, 1, 61, 8, 12)
   rect(135, 3, math.floor(perc * 59), 4, 6)

   -- draw the clock
   local hours = self.clock:hour()
   local minutes = self.clock:minute()

   local colon = ":"
   if (math.floor(time() / 1000) % 2) == 0 then
      colon = " "
   end

   print(zeropad(math.floor(hours)) .. colon .. zeropad(math.floor(minutes)), 197, 2, 11, true)

   -- draw the signal indicator.
   spr(sprites.WIFI+self.signal, 230, 1, 0)

   if #self.messages > 0 then
      local msg = self.messages[1]
      rect(9, 79, 220, 40, 4)
      rect(11, 81, 220, 40, 3)

      spr(msg.sprite, 15, 85, -1, 2, 0, 0, 2, 2)
      local lines = msg.text[msg.text_i]
      local y = 85
      print(msg.text[msg.text_i] or "", 55, 87, 0, true)
      print(msg.text[msg.text_i+1] or "", 55, 97, 0, true)
      print(msg.text[msg.text_i+2] or "", 55, 107, 0, true)
   end
end

function HUD:add_message(s)
   table.insert(self.messages, s)
end

function HUD:update_signal(s)
   self.signal = s
end

function HUD:paused()
   return #self.messages > 0
end

Jobs = {}
function Jobs:new()
   o = {
      jobs = {},
      index = 0,
      completed = {},
      expired = {}, -- some jobs must be completed within a given time.
      signal = 0,
   }
   setmetatable(o, self)
   self.__index = self
   return o
end

function Jobs:add(desc, magnitude, typ, opts)
   job = {}
   opts = opts or {}
   for k, v in pairs(opts) do
      job[k] = v
   end
   job.desc = desc
   job.typ = typ
   job.goal= magnitude
   job.progress = 0
   job.next_tick = 0
   table.insert(self.jobs, job)
   self.index = #self.jobs
end

function Jobs:current()
   return self.jobs[self.index]
end

-- rotates through the list of jobs.
function Jobs:next()
   self.index = self.index + 1
   if self.index > #self.jobs then
      self.index = 1
   end
end

function Jobs:work_problem(t, p)
   -- no jobs, can't work.
   if #(self.jobs) == 0 then
      return false, sprites.JOB_NOTHING
   end

   local job = self:current()
   if not job then
      return false, sprites.JOB_NOTHING
   end

   if not job.no_wifi and self.signal == 0 then
      return false, sprites.JOB_WIFI
   end

   -- are we still locked out?
   if t < job.next_tick then
      return false, sprites.JOB_WAIT
   end

   -- now, can the job be performed by the player at this point?
   -- time restriction?
   if (job.min_t and job.max_t) and
   (t < job.min_t or t > job.max_t) then
      return false, sprites.JOB_TIME
   end

   if job.min_x and job.max_x and
      job.min_y and job.max_y and
      (p.x < job.min_x or p.x > job.max_x or
       p.y < job.min_y or p.y > job.max_y) then
         return false, sprites.JOB_LOCATION
   end

   -- a job may require another job to have been completed first.
   -- check the completed jobs to see if it's been done.
   if job.requires then
      for k, v in pairs(self.completed) do
         if v.desc == job.requires then
            return true, sprites.JOB_OK
         end
      end

      return false, sprites.JOB_PREREQ
   end

   return true, sprites.JOB_OK
end

-- estimated how long until work can happen? useful for the HUD.
function Jobs:can_work(t, p)
   local can, _ = self:work_problem(t, p)
   return can
end

function Jobs:work(t, p)
   if self:can_work(t, p) then
      self:current().progress = self:current().progress + 1
      if self:current().progress >= self:current().goal then
         self:complete()
      end

      -- compute the next work time based on the signal
      self:update_next_tick(t)
   end
end

function Jobs:complete()
   local thejob = self.jobs[self.index]

   table.insert(self.completed, self.jobs[self.index])
   table.remove(self.jobs, self.index)

   -- now, call thejob.cb if it exists
   if thejob.cb then
      thejob.cb()
   end

   self.index = #self.jobs

   sfx(12, "E-5", 30)
end

function Jobs:update_next_tick(t)
   local job = self:current()
   if not job then
      return
   end

   if job.no_wifi then
      job.next_tick = t + JOB_LOCKOUT_TICKS
      return
   end

   job.next_tick = t + ((WIFI_MAX_QUALITY + 1 - self.signal) * JOB_LOCKOUT_TICKS)
end

function Jobs:update_signal(s)
   self.signal = s
end

function Jobs:expire(t)
   local did = false
   for i, v in pairs(self.jobs) do
      if v.max_t and t > v.max_t then
         table.insert(self.expired, v)
         table.remove(self.jobs, i)
         did = true
         if v.expire_cb then
            v.expire_cb()
         end
      end
   end
   if self.index > #self.jobs then
      self.index = #self.jobs
   end

   if did then
      sfx(13, "C-2", 30)
   end

end

-- Clock is a drawn as HUD element, in the top of the screen.
Clock = {}
function Clock:new(ticks_per_hour, start_hour)
   o = {
      ticks_per_hour = ticks_per_hour,
      start_hour = start_hour,
      time = 0,
   }

   setmetatable(o, self)
   self.__index = self
   return o
end

-- Update is called once per non-paused frame.
function Clock:update(_t)
   self.time = self.time + 1
end

-- Number of hours that have passed
function Clock:hour()
   return (self.start_hour + (self.time / self.ticks_per_hour)) % 24
end

function Clock:minute()
   return (self.time % self.ticks_per_hour) / 60
end

function zeropad(x)
   x = math.floor(x)
   if x < 10 and x >= 0 then
      return "0" .. tostring(x)
   end
   return tostring(x)
end

function wifi_distance(aps, x, y)
   local best = 1000000
   for _, ap in pairs(aps) do
      if ap.alive then
         local dx = ap.x - x
         local dy = ap.y - y

         if dx == 0 and dy == 0 then
            return 0
         end

         local d = math.sqrt(dx * dx + dy * dy)
         if d < best then
            best = d
         end
      end
   end

   if best == 1000000 then
      return -1
   end
   return best
end

function wifi_quality(d)
   local orig = d
   -- normalize it to based on the available range, and map to wifi strength
   if d > WIFI_RANGE then
      d = WIFI_RANGE
   end

   local norm = d / WIFI_RANGE

   if norm > .75 then
      return 0
   elseif norm > .5 then
         return 1
   elseif norm > .25 then
      return 2
   end

   return 3
end

-- Mode base
Mode = {}
function Mode:new()
   o = {}
   setmetatable(o, self)
   self.__index = self
   return o
end

function Mode:done()
   return false
end

function Mode:next()
   return TitleScreen:new()
end

function Mode:draw(_camera)
end

function Mode:update(button_state, t)
end

function Mode:draw_hud()
end



-- Game
Game = Mode:new()
function Game:new(clock, aps)
   local jobs = Jobs:new()
   local aps = aps
   local clock = clock

   local notifications = {
      -- Town hall.. 09:30 (60 minutes)
      -- Weekly Town Hall. Have questions? We have answers. Post your questions to the "All Hands" Babbler feed.
      {
         due = (CLOCK_TICKS_PER_HOUR / 2) - (CLOCK_TICKS_PER_HOUR / 6),
         sprite = sprites.ICON_CALENDAR_INVITE,
         text = fill(FILL_COLUMN, "Weekly Town Hall at 09:30. Have questions? We have answers. Post your questions to the \"All Hands\" Babbler feed."),
         text_i = 1,
         cb = function()
            local opts = copy(town_hall_boundaries)
            opts.no_wifi = true
            opts.min_t = CLOCK_TICKS_PER_HOUR / 2
            opts.max_t = (CLOCK_TICKS_PER_HOUR / 2) + CLOCK_TICKS_PER_HOUR
            jobs:add("Town Hall", 30, "Meetings", opts)
         end,
      },

      -- Morning Snack.. 10:30
      -- Morning snack is here for you!

      {
         due = (CLOCK_TICKS_PER_HOUR / 2) + CLOCK_TICKS_PER_HOUR,
         sprite = sprites.ICON_CALENDAR_INVITE,
         text = fill(FILL_COLUMN, "Morning snack is here for you!"),
         text_i = 1,
         cb = function()
            local opts = copy(bathroom_boundaries)
            opts.no_wifi = true
            opts.min_t = (CLOCK_TICKS_PER_HOUR / 2) + CLOCK_TICKS_PER_HOUR
            opts.max_t = CLOCK_TICKS_PER_HOUR * 3
            opts.cb = function()
               local opts = copy(kitchen_prep_boundaries)
               opts.no_wifi = true
               opts.min_t = (CLOCK_TICKS_PER_HOUR / 2) + CLOCK_TICKS_PER_HOUR
               opts.max_t = CLOCK_TICKS_PER_HOUR * 3
               opts.requires = "M. Snack Wash"
               opts.cb = function()
                  local opts = copy(kitchen_boundaries)
                  opts.no_wifi = true
                  opts.min_t = (CLOCK_TICKS_PER_HOUR / 2) + CLOCK_TICKS_PER_HOUR
                  opts.max_t = CLOCK_TICKS_PER_HOUR * 3
                  opts.requires = "Prep M. Snack"
                  jobs:add("Eat M. Snack", 3, "Eating", opts)
               end
               jobs:add("Prep M. Snack", 2, "Eating", opts)
            end
            jobs:add("M. Snack Wash", 1, "Eating", opts)
         end,
      },

      -- Support ticket at 13:15 (should take a random amount of time.)
      -- "Seeing weird things while trying to use Shoulda Queues" was assigned to you.
      {
         due =  math.floor(CLOCK_TICKS_PER_HOUR * 1.8),
         sprite = sprites.ICON_PERSON_BLUE,
         text = fill(FILL_COLUMN, "\"Seeing weird things while trying to use Shoulda Queues\" was assigned to you."),
         text_i = 1,
         cb = function()
            jobs:add("Support ticket", 18, "Interruptions", opts)
         end,
      },

      -- Kickoff Meeting.. 11:00
      -- Project Surefire Kickoff Meeting. I know this isn't a great time for everyone, but we need to get together and figure out how to proceed with the Surefire Project. What are our risks? What's our opportunity? Thanks!
         -- Needs to add a few more issues.

      {
         due = math.floor((CLOCK_TICKS_PER_HOUR * 2) - (CLOCK_TICKS_PER_HOUR / 6)),
         sprite = sprites.ICON_CALENDAR_INVITE,
         text = fill(FILL_COLUMN, "Project Surefire Kickoff Meeting 11:00. I know this isn't a great time for everyone, but we need to get together and figure out how to proceed with the Surefire Project. What are our risks? What's our opportunity? Thanks!"),
         text_i = 1,
         cb = function()
            local opts = copy(lower_conference_1)
            opts.min_t = CLOCK_TICKS_PER_HOUR * 2
            opts.max_t = CLOCK_TICKS_PER_HOUR * 3
            opts.cb = function()
               jobs:add("Surefire Design", 40, "Project Surefire")
               jobs:add("Surefire Proto", 50, "Project Surefire", {requires = "Surefire Design"})
            end
            opts.expire_cb = function()
               jobs:add("Surefire Req Rev", 60, "Project Surefire")
               jobs:add("Surefire Design", 40, "Project Surefire",  {requires = "Surefire Req Rev"})
               jobs:add("Surefire Proto", 60, "Project Surefire", {requires = "Surefire Design"})
            end
            jobs:add("Surefire Kickoff", 20, "Project Surefire", opts)
         end,
      },

      -- Lunch.. Noon. (25 minutes)
      -- Catered by Tacolicious Crepes. The menu today is Kale Salad and deconstructed Gazpacho.

      {
         due = math.floor((CLOCK_TICKS_PER_HOUR * 3) - (CLOCK_TICKS_PER_HOUR / 6)),
         sprite = sprites.ICON_CALENDAR_INVITE,
         text = fill(FILL_COLUMN, "Lunch at 12:00. Catered by Tacolicious Crepes. The menu today is Kale Salda and deconstructed Gazpacho."),
         text_i = 1,
         cb = function()
            local opts = copy(bathroom_boundaries)
            opts.no_wifi = true
            opts.min_t = CLOCK_TICKS_PER_HOUR * 3
            opts.max_t = CLOCK_TICKS_PER_HOUR * 4
            opts.cb = function()
               local opts = copy(kitchen_prep_boundaries)
               opts.no_wifi = true
               opts.min_t = CLOCK_TICKS_PER_HOUR * 3
               opts.max_t = CLOCK_TICKS_PER_HOUR * 4
               opts.requires = "Lunch Wash"
               opts.cb = function()
                  local opts = copy(kitchen_boundaries)
                  opts.no_wifi = true
                  opts.min_t = CLOCK_TICKS_PER_HOUR * 3
                  opts.max_t = CLOCK_TICKS_PER_HOUR * 4
                  opts.requires = "Prep M. Snack"
                  jobs:add("Eat Lunch", 3, "Eating", opts)
               end
               jobs:add("Prep Lunch", 2, "Eating", opts)
            end
            jobs:add("Lunch Wash", 1, "Eating", opts)
         end,
      },

      -- Manager 1:1 13:00 (30 minutes)
      {
         due =  math.floor((CLOCK_TICKS_PER_HOUR * 4) - (CLOCK_TICKS_PER_HOUR / 6)),
         sprite = sprites.ICON_CALENDAR_INVITE,
         text = fill(FILL_COLUMN, "Manager 1:1 -- 13:00 -- Conference Room 1"),
         text_i = 1,
         cb = function()
            local opts = copy(right_conference)
            opts.no_wifi = true
            opts.min_t = CLOCK_TICKS_PER_HOUR * 4
            opts.max_t = (CLOCK_TICKS_PER_HOUR * 4) + (CLOCK_TICKS_PER_HOUR / 2)
            jobs:add("Manager 1:1", 15, "Meetings", opts)
         end,
      },

      {
         due =  math.floor((CLOCK_TICKS_PER_HOUR * 5) + (11 * 60)),
         sprite = sprites.ICON_PERSON_GREYN,
         text = fill(FILL_COLUMN, "[OFFICE] WIFI is down on the east side of the building. We'll let you know what it's back up."),
         text_i = 1,
         cb = function()
            for i, ap in pairs(aps) do
               if ap.x >= 40 then
                  table.remove(aps, i)
               end
            end
         end,
      },

      -- Afternoon snack .. 15:15
      -- Afternoon snack!
      {
         due = math.floor((CLOCK_TICKS_PER_HOUR / 4) + CLOCK_TICKS_PER_HOUR * 6),
         sprite = sprites.ICON_PERSON_GREYN,
         text = fill(FILL_COLUMN, "Hillary brought back some cookies from her trip! They're in the kitchen now!"),
         text_i = 1,
         cb = function()
            local opts = copy(bathroom_boundaries)
            opts.no_wifi = true
            opts.cb = function()
               local opts = copy(kitchen_prep_boundaries)
               opts.no_wifi = true
               opts.requires = "A. Snack Wash"
               opts.cb = function()
                  local opts = copy(kitchen_boundaries)
                  opts.no_wifi = true
                  opts.requires = "Prep A. Snack"
                  jobs:add("Eat A. Snack", 3, "Eating", opts)
               end
               jobs:add("Prep A. Snack", 2, "Eating", opts)
            end
            jobs:add("A. Snack Wash", 1, "Eating", opts)
         end,
      },


      -- Manager bug .. 15:54 --
      -- Hey. I just had a 1:1 with Julien and he mentioned some weird behavior in the soft queue that you worked on 4 years ago. Anyway, I told him you'd take a look. Shouldn't take too long. I'd really appreciate it.

      {
         due =  math.floor((CLOCK_TICKS_PER_HOUR * 6) + (CLOCK_TICKS_PER_HOUR / 3)),
         sprite = sprites.ICON_PERSON_GREEN,
         text = fill(FILL_COLUMN, "Hey! I just had a 1:1 with Julien and he mentioned some weird behavior in the soft queue that you worked on, maybe 4 years ago?. Anyway, I told him you'd take a look. Shouldn't take too long. I'd really appreciate it!"),
         text_i = 1,
         cb = function()
            jobs:add("Help Julien", 23, "Interruptions", opts)
         end,
      },

      -- Paged at 16:34
      -- "DOWN: Toldya is down since 16:29 -- 500 Internal Server Error on shoulda.seen.it.coming"

      {
         due =  math.floor((CLOCK_TICKS_PER_HOUR * 7) + (CLOCK_TICKS_PER_HOUR / 1.9)),
         sprite = sprites.ICON_BEEPER_NOTICE,
         text = fill(FILL_COLUMN, "DOWN: Toldya is down since 16:29 -- 500 Internal Server Error on shoulda.seen.it.coming"),
         text_i = 1,
         cb = function()
            jobs:add("INCIDENT RESPONSE", 7, "Interruptions")
         end,
      },
   }

   -- standard jobs.
   jobs:add("Feature MS #1", 35, "Features")
   jobs:add("Feature MS #2", 30, "Features", {requires = "Feature MS #1"})

   local copier_opts = copy(copier_boundaries)
   copier_opts.no_wifi = true
   copier_opts.cb = function()
      jobs:add("File Expenses", 2, "Administrivia", { requires = "Scan Expenses" })
   end
   jobs:add("Scan Expenses", 2, "Administrivia", copier_opts)

   local player = Player:new(2, 2)
   o = {
      player = player,
      jobs = jobs,
      clock = clock,
      aps = aps,
      coworkers = {
         Coworker:new(sprites.COWORKER_1, {x = 7, y = 8}),
         Coworker:new(sprites.COWORKER_2, {x = 17, y = 2}),
         Coworker:new(sprites.COWORKER_3, {x = 25, y = 4}),
         Coworker:new(sprites.COWORKER_4, {x = 11, y = 6}),
         Coworker:new(sprites.COWORKER_2, {x = 37, y = 12}),
         Coworker:new(sprites.COWORKER_2, {x = 37, y = 12}),
         Coworker:new(sprites.COWORKER_4, {x = 37, y = 12}),
         Coworker:new(sprites.COWORKER_2, {x = 55, y = 3}),
         Coworker:new(sprites.COWORKER_1, {x = 54, y = 17}),
      },
      notifications = notifications,
      hud = HUD:new(clock, jobs, player),
   }

   setmetatable(o, self)
   self.__index = self
   return o
end

function Game:update(button_state, t)
   -- if the clock is at CLOCK_END_HOUR, then... we've gotta prepare to be done.
   if self.clock.time > (CLOCK_TICKS_PER_HOUR * 8) then
      self.game_over = true
      return
   end

   if not self.hud:paused() and not self.paused then
      self.clock:update(t)
      self:update_player(button_state, self.clock.time)

      if #self.notifications > 0 and self.notifications[1].due == self.clock.time then
         self.hud:add_message(self.notifications[1])
         table.remove(self.notifications, 1)
      end

      -- Compute new signal strength
      local signal = wifi_quality(wifi_distance(self.aps, self.player.x, self.player.y))
      self.jobs:expire(self.clock.time)
      self.jobs:update_signal(signal)
      self.hud:update_signal(signal)
   end

   self.hud:update_messages(button_state.AP)
end

function Game:update_player(button_state, t)
   -- if we're accepting input for work, check to see if there's an A button
   -- press... but only if we're sitting down.
   if self.player:can_work() then
      if self.jobs:can_work(self.clock.time, self.player) and button_state.A then
         self.jobs:work(self.clock.time, self.player)
      end
   end

   if button_state.BP then
      self.jobs:next()
      return
   end

   local x = self.player.x
   local y = self.player.y
   local newx = x
   local newy = y

   if button_state.LEFTP then
      newx = x - 1
   elseif button_state.RIGHTP then
      newx = x + 1
   elseif button_state.UPP then
      newy = y - 1
   elseif button_state.DOWNP then
      newy = y + 1
   end

   if self:oktomove(newx, newy) then
      self.player.x = newx
      self.player.y = newy
   end

   local isseat = fget(mget(newx, newy), flags.SEAT)
   if isseat then
      self.player.state = Actor.SITTING
   else
      self.player.state = Actor.STANDING
   end
end

function Game:oktomove(x, y)
   return not (self:occupied(x, y) or fget(mget(x, y), flags.WALL))
end

function Game:occupied(x, y)
   for _, c in pairs(self.coworkers) do
      if c.x == x and c.y == y then
         return true
      end
   end
   return false
end

function Game:done()
   return self.game_over
end

function Game:next()
   return PerformanceEvaluation:new(self.jobs, self.player)
end

function Game:draw(_camera)
   map(self.player.x-15, self.player.y-8, 28, 15, 0, SCREEN_YOFFSET)
   self.player:draw({})
   for _, c in pairs(self.coworkers) do
      c:draw(self.player)
   end
end

function Game:draw_hud()
   self.hud:draw()
end




-- Setup
TitleScreen = Mode:new()
function TitleScreen:new()
   o = {
      blink = false,
      start = false,
   }
   setmetatable(o, self)
   self.__index = self
   return o
end

function TitleScreen:done()
   return self.start
end

function TitleScreen:draw()
   map(27, 0)

   print("Townsend", 20, 20, 11)

   if self.blink then
      print("Press any key to start", 31, 31, 11)
   end
end

function TitleScreen:update(button_state, t)
   self.blink = (t % 60 < 30)
   if button_state.AP or button_state.BP then
      self.start = true
   end
end

function TitleScreen:next()
   local clock = Clock:new(CLOCK_TICKS_PER_HOUR, CLOCK_START_HOUR)

   -- START TIME.. DEBUG
   --  clock.time = CLOCK_TICKS_PER_HOUR * 7
   return Game:new(clock, ACCESS_POINTS)
end

status = {
   COMPLETED = {
      color = 6,
      text = "COMPLETED",
   },
   ON_TRACK = {
      color = 5,
      text = "ON TRACK",
   },
   BEHIND = {
      color = 4,
      text= "BEHIND",
   },
   FAILING = {
      color = 2,
      text = "FAILING",
   },

}

function evaluate(jobs, typ)
   local progress, total = 0, 0
   for _, c in pairs({jobs.completed, jobs.expired, jobs.jobs}) do
      for _, j in pairs(c) do
         if j.typ == typ then
            progress = progress + j.progress
            total = total + j.goal
         end
      end
   end

   perc = progress / total
   if perc >= 1 then
      return status.COMPLETED
   elseif perc > .75 then
      return status.ON_TRACK
   elseif perc > .3 then
      return status.BEHIND
   else
      return status.FAILING
   end
end


PerformanceEvaluation = Mode:new()
function PerformanceEvaluation:new(jobs, player)
   e = {
      ["Feature Work"] = evaluate(jobs, "Features"),
      ["Eating"] = evaluate(jobs, "Eating"),
      ["Meetings"] = evaluate(jobs, "Meetings"),
      ["Interruptions"] = evaluate(jobs, "Interruptions"),
      ["Administrivia"] = evaluate(jobs, "Administrivia"),
      ["Project Surefire"] = evaluate(jobs, "Project Surefire"),
   }

   o = {
      jobs = jobs,
      player = player,
      escaped = false,
      evaluation = e,
   }

   setmetatable(o, self)
   self.__index = self
   return o
end

function PerformanceEvaluation:done()
   return self.escaped
end

function PerformanceEvaluation:next()
   return Credits:new()
end


function PerformanceEvaluation:update(button_state, t)
   if button_state.AP or button_state.BP then
      self.escaped = true
   end
end

function PerformanceEvaluation:draw()
   print("Performance Evaluation", 60, 5, 12)
   i = 1
   spr(sprites.ICON_PERSON_GREEN, 30, 16, -1, 1, 0, 0, 2, 2)
   print("\"We value your contributions.", 50, 18, 12)
   print("You'll be promoted in no time!\"", 50, 25, 12)

   print("Feedback:", 30, 40, 12)
   for k, v in pairs(self.evaluation) do
      print(k, 40, 40 + i*12, 12)
      print(v.text, 150, 40 + i*12, v.color)
      i = i + 1
   end

end

credits_body = {
   "APG made this.",
   "",
   "Thanks to everyone at Heroku,",
   "and Salesforce for making this past",
   "6 years amazing! I'll miss you all!",
   "",
   "twitter: @apgwoz",
   "web: http://apgwoz.com",
   "",
   "Special shout out to my",
   "original Heroku team,",
   "Telemetry, which no longer",
   "exists, and my final team,",
   "SETI.",
}

Credits = Mode:new()
function Credits:new()
   o = {
      lines = credits_body,
      y = 140,
      escaped = false,
   }

   setmetatable(o, self)
   self.__index = self
   return o
end

function Credits:done()
   return self.y > 200 or self.escaped
end

function Credits:update(button_state, t)
   self.y = self.y - .2
   if button_state.AP then
      self.escaped = true
   end
end

function Credits:draw()
   for i, line in ipairs(self.lines) do
      print(line, 20, math.floor(self.y) + (10 * i), 0)
      print(line, 19, math.floor(self.y)-1 + (10 * i), 5)
   end
end


-- start with the TitleScreen
mode = TitleScreen:new()

function OVR()
   if mode ~= nil then
      mode:draw_hud()
   end
end

function TIC()
   button_state = {
      UP = btn(0),
      UPP = btnp(0),
      DOWN = btn(1),
      DOWNP = btnp(1),
      LEFT = btn(2),
      LEFTP = btnp(2),
      RIGHT = btn(3),
      RIGHTP = btnp(3),
      A = btn(4),
      AP = btnp(4),
      B = btn(5),
      BP = btnp(5)
   }

   cls(0)
   mode:update(button_state, t)
   mode:draw()
   t=t+1

   if mode:done() then
      mode = mode:next()
   end
end




-- <TILES>
-- 001:0212121202121112021112110112121202121112021112110112121202121112
-- 002:0212121202121112021112110112121202121112021112110112121202121112
-- 003:0000000021221222111111112212212211111111122122121111111122122122
-- 004:00000000212212221fccaacc2fcacaac1fffffff1f6a6a661fd566ad22122122
-- 005:0000000021221222cbcfdacccbcfcc6affffffffd66fd666d66fdb6d22122122
-- 006:0000000022212212aabcbaf1bbccabf2fffffff1da6d2df1adaa6af122122122
-- 007:221222122777777117777772277cc771277c7772177777712777777217777771
-- 016:eedff0eeeedff0eeeedff0eeeedff0eeeedff0eeeedff0eeeedff0eeeedff0ee
-- 017:eeeeeeeeeeeeeeeeddddddddffffffffffffffff00000000eeeeeeeeeeeeeeee
-- 018:eeeeeeeeeeeeeeeeeeddddddeedfffffeedfffffeedff000eedff0eeeedff0ee
-- 019:eeeeeeeeeeeeeeeeddddd0eefffff0eefffff0ee000ff0eeeedff0eeeedff0ee
-- 020:eedff0eeeedff0eedddff0eefffff0eefffff0ee000000eeeeeeeeeeeeeeeeee
-- 021:eedff0eeeedff0eeeedff0ddeedfffffeedfffffeed00000eeeeeeeeeeeeeeee
-- 022:eeeeeeeeeeeeeeeeddddddddffffffffffffffff000ff000eedff0eeeedff0ee
-- 023:eeeeeeeeeedeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeecc5ccc5c00000000
-- 024:eeeeeec0eeeeee50eeeeeec0eeeeeec0eeedeec0eeeeee50eeeeeec0eeeeeec0
-- 025:0ceeeeee0ceeeeee05eeeede0ceeeeee0ceeeeee0ceeeeee05eeeeee0ceeeeee
-- 032:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeedeeeeeeeeeeeeee
-- 033:efeeefeefeefeeeeeeeeefefefefeeeffdefefeeeefeeefeeeeeefeffefefefe
-- 034:ddddddddddddddedddddddddddddddddddddeddddddddddeddddddedddeddedd
-- 035:dddddddddddeddedddddddddddddddddddddeddddddddddedddeddddddeddedd
-- 036:88888888888888d888888888888888888888d8888888888e888888d888d88e88
-- 037:88888888888e88d888888888888888888888d8888888888e888d888888d88e88
-- 038:88888888888888d88888888800000000eeeeeeee00000000888888d888d88e88
-- 048:efffffffefdd23dfefd322dfefd226dfefdd56dfefd265dfefdddaafefffffff
-- 049:efffffffef00000fef9dddefefededefef9dddefefecccefefffffffefffffff
-- 050:ed0ddddded0dedcded0ddddded0ddddded0ddddded0ddddded0dededed0ddddd
-- 064:eeeeeeeeefffffffefffffffefffffffefffffffefffffffefffffffefffffff
-- 065:efffffffefffffffefffffffefffffffefffffffefffffffefffffffefffffff
-- 066:ef66ffffef66e3cfeffff33fefffffffef77f44fef77ff4fefffefefefffffff
-- 067:fffffffffffffddfffccffffffccfddffffffffffffffccffffffcefffffffff
-- 080:d4444444d4444444d4444444d4444444d4444444d4444444d4444444d4444444
-- 081:44444444444444444444444444444444444444444444444444444444ffffffff
-- 082:dddddddd44444444444444444444444444444444444444444444444444444444
-- 083:4444444f4444444f4444444f4444444f4444444f4444444f4444444f4444444f
-- 084:ddddddddd4444444d4444444d4444444d4444444d4444444d4444444d4444444
-- 085:4444444f4444444f4444444f4444444f4444444f4444444f4444444fffffffff
-- 086:d4444444d4444444d4444444d4444444d4444444d4444444d4444444ffffffff
-- 087:dddddddf4444444f4444444f4444444f4444444f4444444f4444444f4444444f
-- 096:4444444444444444444444444444444444444444444444444444444444444444
-- 097:4444447f4404444f4f048e4f4f04ee4f4f04e84f4f048e4f4404444f4444444f
-- 098:d4444444d4444044d4e840f4d48e40f4d4ee40f4d4e840f4d4444044d7444444
-- 099:dddddddd7444444444ee8e44448ee844444444444000000444ffff4444444444
-- 100:4444444444ffff444000000444444444448ee84444e8ee4444444447ffffffff
-- 101:4444444447456444442267446657527442175244426512444422264444444444
-- 102:4444444444ffff4444feef4444ffef4444ffef4444fccf4444ffff4444444444
-- 103:dddddddd44ffff4444feef4444ffef4444ffef4444fccf4444ffff4444444444
-- 112:eeeeeeeeeeffffeeefddddfeee0000eeef0000feef0000feeeeeeeeeeeeeeeee
-- 113:eeeeeeeeeeeeeeeeef0000feef0000feee0000eeefddddfeeeffffeeeeeeeeee
-- 114:eeeeeeeeeeffefeeee000dfeee000dfeee000dfeee000dfeeeffefeeeeeeeeee
-- 115:eeeeeeeeeefeffeeefd000eeefd000eeefd000eeefd000eeeefeffeeeeeeeeee
-- 128:ddddddddddffffdddfddddfddd0000dddf0000fddf0000fddddddddddddddddd
-- 129:dddddddddddddddddf0000fddf0000fddd0000dddfddddfdddffffdddddddddd
-- 130:ddddddddddffdfdddd000dfddd000dfddd000dfddd000dfdddffdfdddddddddd
-- 131:ddddddddddfdffdddfd000dddfd000dddfd000dddfd000ddddfdffdddddddddd
-- 144:888ecce888888888cc8ccc88cdccccc8cdcaadcccdcaadcccdccccc8cc8ccc88
-- 160:22222222211111111111111118811111181111111811111118111111ffffffff
-- 161:22222222911111119111111118888881111111819111118191111181ffffffff
-- 162:22222222188888121111181211111812111118121111181212222812ffffffff
-- 192:8cccccdd8ccc055d0ccc033d0de00edd0ccf0edddccf0edddddddfff88888888
-- 193:8888888888868888888888888288883888888888888888828888888888883888
-- 224:eeed2deeeed222deed22c222d22ccc2fe222c2feee222feeeee2feeeeeeeeeee
-- 240:eeeeeeeee6e56eeeee6655eee636366eee7576eee65377eeee6656eeeeeeeeee
-- 241:eeeeeeeee7e56eeeee2267ee6657527ee21752eee26512eeee2226eeeeeeeeee
-- 242:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeaa9dd0eea99de0eea99d00eeeeeeeee
-- 243:eeeeeeeeeaaaeeeee99aeeeee999eeeeedddeeeee0edeeeee000eeeeeeeeeeee
-- 244:ddddddddda99d00dda99de0ddaa9dd0ddddddddddddddddddddddddddddddddd
-- </TILES>

-- <SPRITES>
-- 000:00000000000000000000000000000000000000000000000022f0000022f00000
-- 001:0000000000000000000000000000000033f00000003f000033f3f00033f3f000
-- 002:0000000000000000444f00000004f00044f04f00004f04f044f4f4f044f4f4f0
-- 003:5555000000005000555f05000005f05055f05f05005f05f555f5f5f555f5f5f5
-- 016:0cccccc001c11c1000c44c00001cc100000cc00000c14c0000c44c000cccccc0
-- 017:0003000000023000000223000002110020010002100000010000000000020000
-- 018:00022000022c1220021001202100c012200c0003120000310220033001123110
-- 019:00066000066cc66006cffc6066c66c6666cccc6616cffc6106c66c6001166110
-- 021:0022200002111200212001202012002020012020120012100122210000111000
-- 022:0000000005500000000500000500500000500500050505000000000000000000
-- 048:0022200000444000004300000466640004666400049994000090900000909000
-- 049:00fff0000054400000f400000aaaaa000aaaaa0004eee40000e0e00000e0e000
-- 050:0022200000244000002400000111110001111100041114000010100000303000
-- 051:00eee00000e44000004400000e999e0004999400049994000090900000909000
-- 052:002220000024400000220000089368000858e800049994000090900000909000
-- 224:0009900009999999099ee9990999999909ffffff09cccccc09ccc9cc09cc99cc
-- 225:0009900099999990999ee99099999990ffffff90cccccc909999cc909ccccc90
-- 226:555555555555500055550000555000005500004455003334500033c4504040c4
-- 227:5555555505555555000555550000555500005555330005554330055540304055
-- 228:aaaaaaaaaaaa0000aaa02222aa022222aa022244a0223334a02233c4a04240c4
-- 229:aaaaaaaa000aaaaa2200aaaa22200aaa222200aa332220aa433220aa403240aa
-- 230:77777777777700007770ffff770fffff770fff4470ff333470ff33c4704f49c4
-- 231:77777777000777775f007777ff500777ffff007733ff5077433ff077493f4077
-- 232:ddddddddd77ddddd677ddddd677ddddd677ddddd677777dd6777777d6776677d
-- 233:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
-- 240:09ccc9cc09ccc9cc09ccc9cc09ccc9cc09cccccc09cccccc0999999900000000
-- 241:999ccc90ccc9cc909cc9cc90c99ccc90cccccc90cccccc909999999000000000
-- 242:504044c055004444555504005555044355555044555555005555555555555555
-- 243:4430405544300555040555554405555540555555055555555555555555555555
-- 244:a04244c0a0224444a0220400a0220443a0220044a0220a00aa000aaaaaaaaaaa
-- 245:443240aa443220aa040220aa440220aa400220aa0aa020aaaaa00aaaaaaaaaaa
-- 246:70bf44c0700f4444777004007777042277770044777777007777777777777777
-- 247:443fb077443ff077040f5077240ff077400f50770770f0777770077777777777
-- 248:6777777d67777766666666d6ddddddd6ddddddd6ddddddd6ddddddd6ddddddd6
-- 249:77d777dd7777777d7776677d776d677d77dd677d77dd677d77dd677d6ddd66dd
-- </SPRITES>

-- <MAP>
-- 000:203040506030405060304050603040506030405060304050603040506030405060303030304050603030304050603030303040506030405060303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 001:200202020202020205063502020205063502020202020506350202020202020202020202020202020202020202020202020202020202020202020f20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 002:201212121202023726061627023726061627020202372606162702020202020202020202020202020202020202020202020202020202020202020220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 003:2091122a12020202056635020202055635020202020205663502020202020202020202020202020202020202020202020202020202120a0a1a120220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 004:2091121212020237260616270237260616270202020205061627020202020202020202020202020202020202020202020202020202121212122a0220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 005:2091122a12020202055635020202050635020202023726063502020202020202222222222222222222222222222222042002020202121212122a0220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 006:209112121202023726061627023726061627020202020506162702020202020222457528223845752222323232323213200202020202020202020f20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 007:2091122a1202020205563502020205663502020202020556350202020202020238053522222205352822320314323214200202022111111111111120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 008:201212121202023726061627023726061627020202372606162702020202020222053528223805352222320334323223200202020102020202020220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 009:200202020202020265155502020265155502020202026515550202020202020238053522222205352822320334323223200202020102020702070220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 010:200202020202020202020202020202020202020202020202020202020202020222053528223805352222320324323214200202020202452525252520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 011:200202020202020202020202020202020202020202020202020202020202020238053522222205352822320314323224200202020202651515151520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 012:200202020202020202020202020202020202020202020202020202020202020222053528223805352222324f4f323214200202020102021702170220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 013:20020202020202020202020202020202020202020202020202020202020202023805352222220535282222222208322420020202011f717171712f20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 014:20020202020202020202020202020202020202020202020202020202020202022205352822380535222222384575224f200202025111111111111120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 015:200202020202020202020202020202020202020202020202020202020202020238655522222265552822222265552822203f02020245257625252520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 016:200202121212121212121212121212121212120202020202020202020202020222222222222222222222222218222222200c1c020265461515461520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 017:200202120a1a1a12120a1a1a12120a1a1a12120202020202020202020202020202020202020202020202020202020202200c1c020202170202170220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 018:200202121212121212121212121212121212120202020202020202020202020202020202020202020202020202020202200c1c020202020202020220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 019:200202121212121212121212121212121212122a02211102021111111111611102021111111161110202111131020202200c1c020202020202020220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 020:200202120a1a1a12120a1a1a12120a1a1a12120202013f0202020202021f013f02020202020f011f0202028101020202200c1c020245252576252520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 021:200202121212121212121212121212121212122a02010207020702070202010202070207020201020207028101020202020202020265461515461520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 022:200202120812081212081208121208120812120202010245252525257502010245252525750201024525758101020202020202020202170202170220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 023:200202121212121212121212121212121212122a02010265151515155502010265151515550201026515558101020202020202020202020202020220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 024:2002020202020202020202020202020e0202020202010217021702170202010202170217020201020217028101020202020202020202020202020220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 025:200202021f7171717171717171717102021f0202020171717171717171710171717171717171012f0202020201020202020202020202020202020220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 026:203030303030303030303030303030303030303030303030303030303030303030303030302030303030303030303070303030303030703030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 027:000000000000000000000000000000000000000000000000000000000000000000000000000000000000100942424242141009424242421410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 028:000000000000000000000000000000000000000000000000000000000000000000000000000000000000104242424252131042424242521310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 029:000000000000000000000000000000000000000000000000000000000000000000000000000000000000106262624242141062626242421410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 030:000000000000000000000000000000000000000000000000000000000000000000000000000000000000100942424252131009424242521310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 031:000000000000000000000000000000000000000000000000000000000000000000000000000000000000104242424242141042424242421410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 032:000000000000000000000000000000000000000000000000000000000000000000000000000000000000303030303030303030303030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </MAP>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- </WAVES>

-- <SFX>
-- 000:b100b100b100a1009100910091008100810081008100810091009100a100a100b100b100b100b100b100b100b100b100b100b100b100b100b100b100c05000000000
-- 001:f0009000900090009000a000a000a000a000b000b000b000b000b000b000b000b000a000a0009000a000a000b000c000c000d000e000e000e000e000300000000000
-- 002:910011001100210031004100410041004100410031002100010011005100510061008100a10021003100510061007100810091009100a100a100a100404000000000
-- 012:310031003100410041004100410051005100510061006100610061006100610071007100710081008100810081007100510041003100310021002100404000000000
-- 013:0000100010002000200020000000300040005000600060007000800090009000a000a000b000b000c000c000d000e000f000f000f000f000f000f000100000000000
-- </SFX>

-- <PATTERNS>
-- 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000100000100000100000100000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </PATTERNS>

-- <TRACKS>
-- 000:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e200
-- </TRACKS>

-- <FLAGS>
-- 000:00202020202020000000000000000000202020202020205050400000000000001010105010502000000000000000000020202020200000000000000000000000202020200000000000000000000000002020202020202020000000000000000020282020202020200000000000000000404040400000000000000000000000004040404000000000000000000000000040000000000000000000000000000000404040000000000000000000000000000000000000000000000000000000000020400000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000020201010100000000000000000000000
-- </FLAGS>

-- <PALETTE>
-- 000:1a1c2c5d275db13e53ef7d57ffca89a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57
-- </PALETTE>

