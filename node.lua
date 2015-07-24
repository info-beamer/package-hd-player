gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

local json = require "json"

local settings = {
    IMAGE_PRELOAD = 2;
    VIDEO_PRELOAD = 2;
    PRELOAD_TIME = 5;
    FALLBACK_PLAYLIST = {
        {
            duration = 1;
            asset_name = "blank.png";
            type = "image";
        }
    }
}

local function ramp(t_s, t_e, t_c, ramp_time)
    if ramp_time == 0 then return 1 end
    local delta_s = t_c - t_s
    local delta_e = t_e - t_c
    return math.min(1, delta_s * 1/ramp_time, delta_e * 1/ramp_time)
end

local function cycled(items, offset)
    offset = offset % #items + 1
    return items[offset], offset
end

local Config = (function()
    local playlist = {}
    local switch_time = 1

    util.file_watch("config.json", function(raw)
        print "updated config.json"
        local config = json.decode(raw)

        if #config.playlist == 0 then
            playlist = settings.FALLBACK_PLAYLIST
            switch_time = 0
        else
            playlist = {}
            for idx = 1, #config.playlist do
                local item = config.playlist[idx]
                if item.duration > 0 then
                    playlist[#playlist+1] = {
                        duration = item.duration,
                        asset_name = item.file.asset_name,
                        type = item.file.type,
                    }
                end
            end
            switch_time = config.switch_time
        end

    end)

    return {
        get_playlist = function() return playlist end;
        get_switch_time = function() return switch_time end;
    }
end)()

local Scheduler = (function()
    local playlist_offset = 0

    local function get_next()
        local playlist = Config.get_playlist()
        local item
        item, playlist_offset = cycled(playlist, playlist_offset)
        print(string.format("next scheduled item is %s [%f]", item.asset_name, item.duration))
        return item
    end

    return {
        get_next = get_next;
    }
end)()

local ImageJob = function(item, ctx, fn)
    fn.wait_t(ctx.starts - settings.IMAGE_PRELOAD)

    local res = resource.load_image(ctx.asset)

    for now in fn.wait_next_frame do
        local state, err = res:state()
        if state == "loaded" then
            break
        elseif state == "error" then
            error("preloading failed: " .. err)
        end
    end

    print "waiting for start"
    fn.wait_t(ctx.starts)
    print "starting"

    for now in fn.wait_next_frame do
        util.draw_correct(res, 0, 0, WIDTH, HEIGHT, ramp(
            ctx.starts, ctx.ends, now, Config.get_switch_time()
        ))
        if now > ctx.ends then
            break
        end
    end

    res:dispose()
    print "image job completed"
    return true
end


local VideoJob = function(item, ctx, fn)
    fn.wait_t(ctx.starts - settings.IMAGE_PRELOAD)

    local raw = sys.get_ext "raw_video"
    local res = raw.load_video(ctx.asset, false, false, true)

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
    print "starting"

    local _, width, height = res:state()
    res:layer(1):start()

    local x1, y1, x2, y2 = util.scale_into(WIDTH, HEIGHT, width, height)

    for now in fn.wait_next_frame do
        res:target(x1, y1, x2, y2, ramp(
            ctx.starts, ctx.ends, now, Config.get_switch_time()
        ))
        if now > ctx.ends then
            break
        end
    end

    fn.wait_next_frame()
    res:dispose()
    print "video job completed"
    return true
end


local Queue = (function()
    local jobs = {}
    local next_item_time = sys.now()

    local function add_job(item)
        local co = coroutine.create(({
            image = ImageJob,
            video = VideoJob,
        })[item.type])

        local success, asset = pcall(resource.open_file, item.asset_name)
        if not success then
            print("CANNOT GRAB ASSET: ", asset)
            return
        end

        local ctx = {
            starts = next_item_time,
            ends = next_item_time + item.duration;
            asset = asset;
        }

        local success, err = coroutine.resume(co, item, ctx, {
            wait_next_frame = function ()
                return coroutine.yield(false)
            end;
            wait_t = function(t)
                while true do
                    local now = coroutine.yield(false)
                    if now >= t then
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
        }

        next_item_time = next_item_time + item.duration
        print("added job. next start time is ", next_item_time)
    end

    local function tick()
        for try = 1,3 do
            if next_item_time - sys.now() > settings.PRELOAD_TIME then
                break
            end
            add_job(Scheduler.get_next())
        end

        local now = sys.now()
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
    end

    return {
        tick = tick;
    }
end)()

util.set_interval(1, node.gc)

function node.render()
    gl.clear(0, 0, 0, 1)
    Queue.tick()
end
