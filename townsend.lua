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

-- (MAX_SIGNAL - signal) * JOB_LOCKOUT_TICKS
JOB_LOCKOUT_TICKS = 60

-- Vertical space for top bar.
SCREEN_YOFFSET = 10

-- TODO: This should really not be global...
ACCESS_POINTS = {
   {x = 20, y = 2, alive = true},
   {x = 1, y = 13, alive = true},
}

sprites = {
   WIFI = 256,
   PLAYER = 304,
   COWORKER_1 = 444,
   COWORKER_2 = 444,

   JOB_WAIT = 272,
   JOB_LOCATION = 273,
   JOB_TIME = 274,
   JOB_OK = 275,
   JOB_NOTHING = 276,
}

flags = {
   FLOOR = 0,
   WALL = 1,
   SEAT = 2
}

Actor = {
   STANDING = 1,
   SITTING = 2,
   TALKING = 3,

   -- these are placeholders for when sprites actually exist to do offsets from.
   LEFT = 10,
   RIGHT = 11,
   UP = 12,
   DOWN = 13
}

function Actor:new(o)
   o = o or {
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
      direction = LEFT,
      state = self.STANDING,
   }
   setmetatable(o, self)
   self.__index = self
   return o
end

function Player:can_work(t)
   return self.state == self.SITTING
end

function Player:draw()
   spr(sprites.PLAYER, self.x * 8, SCREEN_YOFFSET + (self.y * 8), 0)
end

function Player:can_work(t)
   return self.state == self.SITTING
end

Coworker = Actor:new()
function Coworker:draw()
   circ(self.x, self.y, 5, 1)
end

HUD = {}
function HUD:new(clock, jobs, player)
   o = {
      jobs = jobs,
      clock = clock,
      player = player,
      signal = 0,
   }
   setmetatable(o, self)
   self.__index = self
   return o
end

function HUD:draw()
   -- draw the can work indicator.
   _, problem = self.jobs:work_problem(self.clock.time, self.player)
   spr(problem, 1, 1, 0)

   -- draw the jobs status.
   print(zeropad(#(self.jobs.completed)), 12, 2, 10)
   print("/", 24, 2, 11)
   print(zeropad(#(self.jobs.completed)+#(self.jobs.jobs)), 30, 2, 11)

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
   rectb(90, 1, 104, 8, 12)
   rect(92, 3, math.floor(perc * 100), 4, 6)

   -- draw the clock
   local hours = self.clock:hour()
   local minutes = self.clock:minute()

   local colon = ":"
   if (math.floor(time() / 1000) % 2) == 0 then
      colon = " "
   end

   print(zeropad(math.floor(hours)) .. colon .. zeropad(math.floor(minutes)), 200, 2, 11)

   -- draw the signal indicator.
   spr(sprites.WIFI+self.signal, 230, 1, 0)


   -- represent the jobs and progress made.

   -- hud box for notifications
   -- if #self.messages > 0 then
   --    rect(10, 96, 220, 30, 1)
   --    rect(11, 97, 220, 30, 2)

   --    print(self.messages[1], 15, 59, 101)
   -- end
end

function HUD:update_signal(s)
   self.signal = s
end

Jobs = {}
function Jobs:new()
   o = {
      jobs = {},
      index = 0,
      completed = {},
      expired = {}, -- some jobs must be completed within a given time.
      signal = 0,
      lockout_until = 0, -- can work be done?
   }
   setmetatable(o, self)
   self.__index = self
   return o
end

function Jobs:add(desc, magnitude, opts)
   job = {}
   opts = opts or {}
   for k, v in pairs(opts) do
      job[k] = v
   end
   job.desc = desc
   job.goal= magnitude
   job.progress = 0
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
   trace(self.index .. " is the new one")
end

-- TODO: Probably need to expire some jobs
function Jobs:work_problem(t, p)
   -- no jobs, can't work.
   if #(self.jobs) == 0 then
      return false, sprites.JOB_NOTHING
   end

   -- are we still locked out?
   if t < self.lockout_until then
      return false, sprites.JOB_WAIT
   end

   -- now, can the job be performed by the player at this point?
   job = self:current()

   -- time restriction?
   if job.min_t and job.max_t and
   t < job.min_t and t > job.max_t then
      return false, sprites.JOB_TIME
   end

   trace("job contraints (" ..
            tostring(job.min_x) .. ", " .. tostring(job.min_y) .. ") (" ..
            tostring(job.max_x) .. ", " .. tostring(job.max_y) .. ")")
   trace("   person = " .. p.x .. ", " .. p.y)

   if job.min_x and job.max_x and
      job.min_y and job.max_y and
      (p.x < job.min_x or p.x > job.max_x or
       p.y < job.min_y or p.y > job.max_y) then
         return false, sprites.JOB_LOCATION
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
      self:update_lockout(t)
   end
end

function Jobs:complete()
   table.insert(self.completed, self.jobs[self.index])
   self.jobs[self.index] = nil
   self.index = #self.jobs
end


function Jobs:update_lockout(t)
   self.lockout_until = t + ((WIFI_MAX_QUALITY + 1 - self.signal) * JOB_LOCKOUT_TICKS)
end

function Jobs:update_signal(s)
   self.signal = s
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
   for _, ap in ipairs(aps) do
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

function Mode:draw()
end

function Mode:update(button_state, t)
end

function Mode:draw_hud()
end


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
   print("Townsend", 20, 20, 14)

   if self.blink then
      print("Press any key to start", 40, 40, 11)
   end
end

function TitleScreen:update(button_state, t)
   self.blink = (t % 60 < 30)
   if button_state.AP then
      self.start = true
   end
end

function TitleScreen:next()
   local clock = Clock:new(CLOCK_TICKS_PER_HOUR, CLOCK_START_HOUR)
   return Game:new(clock, ACCESS_POINTS)
end


-- Game
Game = Mode:new()
function Game:new(clock, aps)
   local jobs = Jobs:new()
   jobs:add("bug", 30)
   jobs:add("lunch", 5, {min_x = 15, max_x = 27,
                         min_y = 11, max_y = 14})

   local player = Player:new(2, 2)
   o = {
      player = player,
      jobs = jobs,
      clock = clock,
      aps = aps,
      hud = HUD:new(clock, jobs, player),
   }

   setmetatable(o, self)
   self.__index = self
   return o
end

function Game:update(button_state, t)
   -- if the clock is at CLOCK_END_HOUR, then... we've gotta prepare to be done.
   if self.clock:hour() == CLOCK_END_HOUR then
      -- prepare for game over.
   end

   self.clock:update(t)
   self:update_player(button_state, self.clock.time)

   -- Compute new signal strength
   signal = wifi_quality(wifi_distance(self.aps, self.player.x, self.player.y))
   self.hud:update_signal(signal)
   self.jobs:update_signal(signal)
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

   local iswall = fget(mget(newx, newy), flags.WALL)
   if not iswall then
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

function Game:done()

end

function Game:next()
   if self.game_over then
      return ScoreCard:new(self.jobs)
   end
   return Credits:new()
end

function Game:draw()
   map(0, 0, 28, 15, 0, SCREEN_YOFFSET)
   self.player:draw()
end

function Game:draw_hud()
   self.hud:draw()
end

ScoreCard = Mode:new()
function ScoreCard:new(jobs)
   o = {
      jobs = jobs,
      escaped = false,
   }
   setmetatable(o, self)
   self.__index = self
   return o
end

function ScoreCard:done()
   return self.escaped
end

function ScoreCard:update(button_state, t)
   if button_state.AP or button_state.BP then
      self.escaped = true
   end
end

function ScoreCard:draw()
   for i, j in pairs(self.jobs.jobs) do
      print("SCORE", 0, 0)
   end
end


credits_body = {
   "Game by APG",
   "Written by APG",
   "Graphics by APG",
   "Sound by APG",
   "Original concepts by APG",
   "",
   "With Special Thanks to Heroku",
   "     ... and Salesforce",
   "Alex Arnell",
   "Edward Muller",
   "Phil Hagelberg",
   "Peter Baker"
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

-- Setup
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
-- 001:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeedeeeeeeeeeeeeee
-- 002:0212121202121112021112110112121202121112021112110112121202121112
-- 003:0000000021221222111111112212212211111111122122121111111122122122
-- 004:eeeeeeeeeffff33ee444443ee333343ee333343ee444443eeffff33eeeeeeeee
-- 005:eeeeeeeee33ffffee344444ee343333ee343333ee344444ee33ffffeeeeeeeee
-- 017:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 081:4444444444444444444444444444444444444444444444444444444444444444
-- 097:444444744440444444f048e444f04ee444f04e8444f048e44440444444444444
-- 098:44444444444404444e840f4448e40f444ee40f444e840f444444044447444444
-- </TILES>

-- <SPRITES>
-- 000:00000000000000000000000000000000000000000000000022f0000022f00000
-- 001:0000000000000000000000000000000033f00000003f000033f3f00033f3f000
-- 002:0000000000000000444f00000004f00044f04f00004f04f044f4f4f044f4f4f0
-- 003:5555000000005000555f05000005f05055f05f05005f05f555f5f5f555f5f5f5
-- 016:0cccccc000c00c0000c44c00000cc000000cc00000c04c0000c44c000cccccc0
-- 017:0003000000023000000223000002000020000002000000000000000000020000
-- 018:00022000022c0220020000202000c002200c0003020000300220033000023000
-- 019:00066000066cc66006cffc6066c66c6666cccc6606cffc6006c66c6000066000
-- 048:0022200000444000004300000466640004666400049994000090900000909000
-- </SPRITES>

-- <MAP>
-- 000:203030303030303030303030303030303030303030303030303030302000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 001:201010101515101010151510101015151010101010101010101010102000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 002:201010502616401010261640105026164010101010101010101010102000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 003:201010101515101010151510101015151010101010101010101010102000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 004:201010502616401010261640105026164010101010101010101010102000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 005:201010101515101010151510101015151010101010101010101010102000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 006:201010101010101010101010101010101010101010101010101010102000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 007:201010101010101010101010101010101010101010101010101010102000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 008:201010101010101010101010101010101010101010101010101010102000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 009:201010101010101010101010101010101010101010101010101010102000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 010:201010501040101010101010101010111111111111111111111150152000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 011:201010501040101010101010101010111150151540111111111111152000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 012:201010101010101010101010101010111111151511111111111150152000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 013:201010101010101010101010101010111150151540111111111111152000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 014:003030303030303030303030303030111111111111111111303030302000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 015:000000000000000000000000000020303030303030303030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </MAP>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- </WAVES>

-- <SFX>
-- 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000304000000000
-- </SFX>

-- <FLAGS>
-- 000:00102020404000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000282000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </FLAGS>

-- <PALETTE>
-- 000:1a1c2c5d275db13e53ef7d57ffca89a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57
-- </PALETTE>

