gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

util.no_globals()

local json = require "json"
local legacy_hevc = not sys.provides "kms"

local now = os.time()

if legacy_hevc then
    print "Using legacy HEVC playback with non-overlapping decoders"
end

local function printf(fmt, ...)
    return print(string.format(fmt, ...))
end

local shaders = {
    multisample = resource.create_shader[[
        uniform sampler2D Texture;
        varying vec2 TexCoord;
        uniform vec4 Color;
        uniform float x, y, s;
        void main() {
            vec2 texcoord = TexCoord * vec2(s, s) + vec2(x, y);
            vec4 c1 = texture2D(Texture, texcoord);
            vec4 c2 = texture2D(Texture, texcoord + vec2(0.0002, 0.0002));
            gl_FragColor = (c2+c1)*0.5 * Color;
        }
    ]], 
    simple = resource.create_shader[[
        uniform sampler2D Texture;
        varying vec2 TexCoord;
        uniform vec4 Color;
        uniform float x, y, s;
        void main() {
            gl_FragColor = texture2D(Texture, TexCoord * vec2(s, s) + vec2(x, y)) * Color;
        }
    ]], 
    progress = resource.create_shader[[
        uniform sampler2D Texture;
        varying vec2 TexCoord;
        uniform float progress_angle;

        float interp(float x) {
            return 2.0 * x * x * x - 3.0 * x * x + 1.0;
        }

        void main() {
            vec2 pos = TexCoord;
            float angle = atan(pos.x - 0.5, pos.y - 0.5);
            float dist = clamp(distance(pos, vec2(0.5, 0.5)), 0.0, 0.5) * 2.0;
            float alpha = interp(pow(dist, 8.0));
            if (angle > progress_angle) {
                gl_FragColor = vec4(1.0, 1.0, 1.0, alpha);
            } else {
                gl_FragColor = vec4(0.5, 0.5, 0.5, alpha);
            }
        }
    ]]
}

local settings = {
    IMAGE_PRELOAD = 2;
    VIDEO_PRELOAD = 2;
    PRELOAD_TIME = 5;
    HEVC_LOAD_TIME = 0.5;
}

local white = resource.create_colored_texture(1,1,1,1)
local black = resource.create_colored_texture(0,0,0,1)
local font = resource.load_font "roboto.ttf"

local function ramp(t_s, t_e, t_c, ramp_time)
    if ramp_time == 0 then return 1 end
    local delta_s = t_c - t_s
    local delta_e = t_e - t_c
    return math.min(1, delta_s * 1/ramp_time, delta_e * 1/ramp_time)
end

local function expand_schedule(config, schedule)
    if schedule == 'always' or schedule == 'never' then
        return schedule
    end
    return config.__schedules.expanded[schedule+1]
end

local function is_schedule_active_at(schedule, probe_time)
    if schedule == "always" then
        return true
    elseif schedule == "never" then
        return false
    end
    local probe_time = os.time()
    if probe_time < 10000000 then
        return false -- no valid system time, don't schedule
    end
    for _, range in ipairs(schedule) do
        local starts, duration = unpack(range)
        if starts > probe_time then
            break
        elseif probe_time < starts + duration then
            return true
        end
    end
    return false
end

local Config = (function()
    local playlist = {}
    local synced = false
    local portrait = false
    local rotation = 0
    local progress = "no"
    local transform = function() end
    local idle_img = nil

    local config_file = "config.json"

    -- You can put a static-config.json file into the package directory.
    -- That way the config.json provided by info-beamer hosted will be
    -- ignored and static-config.json is used instead.
    --
    -- This allows you to import this package bundled with images/
    -- videos and a custom generated configuration without changing
    -- any of the source code.
    if CONTENTS["static-config.json"] then
        config_file = "static-config.json"
        print "[WARNING]: will use static-config.json, so config.json is ignored"
    end

    util.json_watch(config_file, function(config)
        print("updated " .. config_file)

        synced = config.synced
        progress = config.progress

        if config.idle.filename == "loading.png" then
            idle_img = nil
        else
            idle_img = resource.load_image(config.idle.asset_name)
        end

        rotation = config.rotation
        portrait = rotation == 90 or rotation == 270

        gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)
        transform = util.screen_transform(rotation)

        playlist = {}
        for _, item in ipairs(config.playlist) do
            if item.duration > 0 then
                local format = item.file.metadata and item.file.metadata.format
                local duration = item.duration + (
                    -- On legacy OS versions prior to v14:
                    -- Stretch play slot by HEVC load time, as HEVC
                    -- decoders cannot overlap, so we have to load
                    -- the video while we're scheduled, instead
                    -- of preloading... maybe that'll change in the
                    -- future.
                    (format == "hevc" and legacy_hevc) and settings.HEVC_LOAD_TIME or 0
                )
                playlist[#playlist+1] = {
                    duration = duration,
                    format = format,
                    asset = resource.open_file(item.file.asset_name),
                    type = item.file.type,
                    schedule = expand_schedule(config, item.schedule),

                    -- include playlist properties for simplicity
                    audio = config.audio,
                    switch_time = config.switch_time,
                    kenburns = config.kenburns,
                }
            end
        end

        node.gc()
    end)

    local function get_playlist_at(t)
        local scheduled_playlist = {}
        local offset = 0
        for _, item in ipairs(playlist) do
            if is_schedule_active_at(item.schedule, t) then
                item.offset = offset
                scheduled_playlist[#scheduled_playlist+1] = item
                offset = offset + item.duration
            end
        end
        if #playlist > 0 then
            printf("%d/%d scheduled playlist items of %.4fs", #scheduled_playlist, #playlist, offset)
        end
        return scheduled_playlist, offset
    end

    return {
        get_playlist_at = get_playlist_at;
        get_idle_img = function() return idle_img end;
        get_synced = function() return synced end;
        get_progress = function() return progress end;
        get_rotation = function() return rotation, portrait end;
        apply_transform = function() return transform() end;
    }
end)()

local function draw_progress(starts, ends, now)
    local mode = Config.get_progress()
    if mode == "no" then
        return
    end

    if ends - starts < 2 then
        return
    end

    local progress = 1.0 / (ends - starts) * (now - starts)
    if mode == "bar_thin_white" then
        white:draw(0, HEIGHT-10, WIDTH*progress, HEIGHT, 0.5)
    elseif mode == "bar_thick_white" then
        white:draw(0, HEIGHT-20, WIDTH*progress, HEIGHT, 0.5)
    elseif mode == "bar_thin_black" then
        black:draw(0, HEIGHT-10, WIDTH*progress, HEIGHT, 0.5)
    elseif mode == "bar_thick_black" then
        black:draw(0, HEIGHT-20, WIDTH*progress, HEIGHT, 0.5)
    elseif mode == "circle" then
        shaders.progress:use{
            progress_angle = math.pi - progress * math.pi * 2
        }
        white:draw(WIDTH-40, HEIGHT-40, WIDTH-10, HEIGHT-10)
        shaders.progress:deactivate()
    elseif mode == "countdown" then
        local remaining = math.ceil(ends - now)
        local text
        if remaining >= 60 then
            text = string.format("%d:%02d", remaining / 60, remaining % 60)
        else
            text = remaining
        end
        local size = 32
        local w = font:width(text, size)
        black:draw(WIDTH - w - 4, HEIGHT - size - 4, WIDTH, HEIGHT, 0.6)
        font:write(WIDTH - w - 2, HEIGHT - size - 2, text, size, 1,1,1,0.8)
    end
end

local Idle = (function()
    local loading = "Loading"
    local size = 80
    local w = font:width(loading, size)

    -- in range -1 to 1. This gives it a 1 second threshold before
    -- it becomes active.
    local alpha = -1
    
    local function draw()
        if alpha <= 0 then
            return
        end
        local img = Config.get_idle_img()
        if img then
            util.draw_correct(img, 0, 0, WIDTH, HEIGHT, alpha)
        else
            font:write(
                (WIDTH-w)/2, (HEIGHT-size)/2, 
                loading .. ("..."):sub(1, math.floor((sys.now()*2) % 3)+1), size,
                1,1,1,alpha
            )
        end
    end

    local function fade_in()
        alpha = math.min(1, alpha + 1/60)
    end

    local function fade_out()
        alpha = math.max(-1, alpha - 1/60)
    end

    return {
        fade_in = fade_in;
        fade_out = fade_out;
        draw = draw;
    }
end)()

local content_on_screen

local ImageJob = function(item, ctx, fn)
    fn.wait_t(ctx.starts - settings.IMAGE_PRELOAD)

    local res = resource.load_image(item.asset:copy())

    for now in fn.wait_next_frame do
        local state, err = res:state()
        if state == "loaded" then
            break
        elseif state == "error" then
            error("preloading failed: " .. err)
        end
    end

    print "waiting for start"
    local starts = fn.wait_t(ctx.starts)
    local duration = ctx.ends - starts

    print(">>> IMAGE", res, ctx.starts, ctx.ends)

    if item.kenburns then
        local function lerp(s, e, t)
            return s + t * (e-s)
        end

        local paths = {
            {from = {x=0.0,  y=0.0,  s=1.0 }, to = {x=0.08, y=0.08, s=0.9 }},
            {from = {x=0.05, y=0.0,  s=0.93}, to = {x=0.03, y=0.03, s=0.97}},
            {from = {x=0.02, y=0.05, s=0.91}, to = {x=0.01, y=0.05, s=0.95}},
            {from = {x=0.07, y=0.05, s=0.91}, to = {x=0.04, y=0.03, s=0.95}},
        }

        math.randomseed(ctx.starts)
        local path = paths[math.random(1, #paths)]

        local to, from = path.to, path.from
        if math.random() >= 0.5 then
            to, from = from, to
        end

        local w, h = res:size()
        local multisample = w / WIDTH > 0.8 or h / HEIGHT > 0.8
        local shader = multisample and shaders.multisample or shaders.simple
        
        while true do
            local t = (now - starts) / duration
            shader:use{
                x = lerp(from.x, to.x, t);
                y = lerp(from.y, to.y, t);
                s = lerp(from.s, to.s, t);
            }
            util.draw_correct(res, 0, 0, WIDTH, HEIGHT, ramp(
                ctx.starts, ctx.ends, now, item.switch_time
            ))
            draw_progress(ctx.starts, ctx.ends, now)
            content_on_screen = true
            if now > ctx.ends then
                break
            end
            fn.wait_next_frame()
        end
    else
        while true do
            util.draw_correct(res, 0, 0, WIDTH, HEIGHT, ramp(
                ctx.starts, ctx.ends, now, item.switch_time
            ))
            if not item.idle then
                draw_progress(ctx.starts, ctx.ends, now)
            end
            content_on_screen = true
            if now > ctx.ends then
                break
            end
            fn.wait_next_frame()
        end
    end

    print("<<< IMAGE", res, ctx.starts, ctx.ends)
    res:dispose()

    return true
end


local VideoJob = function(item, ctx, fn)
    fn.wait_t(ctx.starts - settings.VIDEO_PRELOAD)

    local res = resource.load_video{
        file = item.asset:copy(),
        audio = item.audio,
        looped = false,
        paused = true,
        raw = true,
    }

    for now in fn.wait_next_frame do
        local state, err = res:state()
        if state == "paused" then
            break
        elseif state == "error" then
            error("preloading failed: " .. err)
        end
    end

    print "waiting for start"
    fn.wait_t(ctx.starts)

    print(">>> VIDEO", res, ctx.starts, ctx.ends)
    res:start()

    while true do
        local rotation, portrait = Config.get_rotation()
        local state, width, height = res:state()
        if state ~= "finished" then
            local layer = -2
            if now > ctx.starts + 0.1 then
                -- after the video started, put it on a more
                -- foregroundy layer. that way two videos
                -- played after one another are sorted in a
                -- predictable way and no flickering occurs.
                layer = -1
            end
            if portrait then
                width, height = height, width
            end
            local x1, y1, x2, y2 = util.scale_into(NATIVE_WIDTH, NATIVE_HEIGHT, width, height)
            res:layer(layer):alpha(ramp(
                ctx.starts, ctx.ends, now, item.switch_time
            )):place(x1, y1, x2, y2, rotation)
        end
        draw_progress(ctx.starts, ctx.ends, now)
        content_on_screen = true
        if now > ctx.ends then
            break
        end
        fn.wait_next_frame()
    end

    print("<<< VIDEO", res, ctx.starts, ctx.ends)
    res:dispose()

    return true
end

local LegacyHEVCJob = function(item, ctx, fn)
    fn.wait_t(ctx.starts)

    local res = resource.load_video{
        file = item.asset:copy(),
        audio = item.audio,
        looped = false,
        paused = true,
        raw = true,
    }

    for now in fn.wait_next_frame do
        local state, err = res:state()
        if state == "paused" then
            break
        elseif state == "error" then
            error("preloading failed: " .. err)
        end
    end

    print "waiting for start"
    fn.wait_t(ctx.starts + settings.HEVC_LOAD_TIME)

    print(">>> VIDEO", res, ctx.starts, ctx.ends)
    res:start()

    while true do
        local rotation, portrait = Config.get_rotation()
        local state, width, height = res:state()
        if state ~= "finished" then
            if portrait then
                width, height = height, width
            end
            local x1, y1, x2, y2 = util.scale_into(NATIVE_WIDTH, NATIVE_HEIGHT, width, height)
            res:layer(-1):alpha(ramp(
                ctx.starts+settings.HEVC_LOAD_TIME, ctx.ends, now, item.switch_time
            )):place(x1, y1, x2, y2, rotation)
        end
        draw_progress(ctx.starts+settings.HEVC_LOAD_TIME, ctx.ends, now)
        content_on_screen = true
        if now > ctx.ends then
            break
        end
        fn.wait_next_frame()
    end

    print("<<< VIDEO", res, ctx.starts, ctx.ends)
    res:dispose()

    return true
end

local Queue = (function()
    local jobs = {}

    local function enqueue(starts, ends, item)
        printf('enqueueing from %.4f to %.4f (in %.4fs)', starts, ends, starts-now)
        local co = coroutine.create(({
            image = ImageJob,
            video = ({
                h264 = VideoJob,
                hevc = legacy_hevc and LegacyHEVCJob or VideoJob,
            })[item.format],
        })[item.type])

        -- an image may overlap another image
        if #jobs > 0 and jobs[#jobs].type == "image" and item.type == "image" then
            starts = starts - item.switch_time
        end

        local ctx = {
            starts = starts,
            ends = ends,
        }

        local success, err = coroutine.resume(co, item, ctx, {
            wait_next_frame = function ()
                return coroutine.yield(false)
            end;
            wait_t = function(t)
                while true do
                    local now = coroutine.yield(false)
                    if now > t then
                        return now
                    end
                end
            end;
        })

        if not success then
            print("CANNOT START JOB: ", err)
            return
        end

        jobs[#jobs+1] = {
            co = co;
            ctx = ctx;
            type = item.type;
        }
    end

    local scheduled_until = 0
    local function schedule_synced()
        if now < 100000 then
            return
        end

        if now > scheduled_until then
            -- missed scheduling. reset attempt
            scheduled_until = now
        end

        local playlist, total_duration = Config.get_playlist_at(scheduled_until)
        if #playlist == 0 then
            return
        end

        printf("unix now: %.4f", now)

        for idx = 1, #playlist+1 do
            -- Find the first item with a start time basically (with a 0.05 margin)
            -- after the current scheduled_until time. Do this by calculating the total
            -- play cycle since 1970 and getting each item's start time based on that.
            local item = playlist[(idx-1) % #playlist + 1]
            local item_cycle = math.floor((idx-1) / #playlist)
            local cycle = math.floor(scheduled_until / total_duration) + item_cycle
            local loop_base = cycle * total_duration
            local starts = loop_base + item.offset
            printf("item probe %d, cycle %d, starts %.4f (%.4fs after scheduled)",
                idx, cycle, starts, starts - scheduled_until
            )
            if starts > scheduled_until - 0.05 then
                printf("scheduled until is %.4f", scheduled_until)
                local ends = starts + item.duration
                enqueue(starts, ends, item)
                scheduled_until = ends
                return
            end
        end
        scheduled_until = now + 1
        print 'nothing found to schedule'
    end

    local offset = 0
    local function schedule_cycle()
        local playlist = Config.get_playlist_at(now)
        if #playlist == 0 then
            return
        end
        offset = offset % #playlist + 1
        local item = playlist[offset]
        local starts = math.max(now, scheduled_until)
        local ends = starts + item.duration
        enqueue(starts, ends, item)
        scheduled_until = ends
        return playlist[offset]
    end

    local function tick()
        if Config.get_synced() then
            if now + settings.PRELOAD_TIME > scheduled_until then
                schedule_synced()
            end
        else
            if now + settings.PRELOAD_TIME > scheduled_until then
                schedule_cycle()
            end
        end

        for idx = #jobs,1,-1 do -- iterate backwards so we can remove finished jobs
            local job = jobs[idx]
            local success, is_finished = coroutine.resume(job.co, now)
            if not success then
                print("CANNOT RESUME JOB: ", is_finished)
                table.remove(jobs, idx)
            elseif is_finished then
                table.remove(jobs, idx)
            end
        end

        if not content_on_screen then
            Idle.fade_in()
        else
            Idle.fade_out()
        end

        Idle.draw()
    end

    return {
        tick = tick;
    }
end)()

util.set_interval(1, node.gc)

function node.render()
    now = os.time()
    content_on_screen = false
    gl.clear(0, 0, 0, 0)
    Config.apply_transform()
    Queue.tick()
end
