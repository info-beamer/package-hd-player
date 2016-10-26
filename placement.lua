local matrix = require "matrix"

local Screen = function(target)
    local screen = sys.get_ext "screen"
    local setup, surface2screen

    gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)
    screen.set_render_target(target.x, target.y, target.width, target.height, true)
    if target.rotation == 0 then
        setup = function()
        end
        surface2screen = matrix.trans(target.x, target.y) *
                         matrix.scale(
                             target.width / NATIVE_WIDTH,
                             target.height / NATIVE_HEIGHT
                         )
    elseif target.rotation == 90 then
        WIDTH, HEIGHT = HEIGHT, WIDTH
        setup = function()
            gl.translate(NATIVE_WIDTH, 0)
            gl.rotate(90, 0, 0, 1)
        end
        surface2screen = matrix.trans(target.x + target.width, target.y) *
                         matrix.scale(
                             target.width / NATIVE_WIDTH,
                             target.height / NATIVE_HEIGHT
                         ) *
                         matrix.rotate(target.rotation / 180 * math.pi)
     elseif target.rotation == 180 then
        setup = function()
            gl.translate(NATIVE_WIDTH, NATIVE_HEIGHT)
            gl.rotate(180, 0, 0, 1)
        end
        surface2screen = matrix.trans(target.x + target.width, target.y + target.height) *
                         matrix.scale(
                             target.width / NATIVE_WIDTH,
                             target.height / NATIVE_HEIGHT
                         ) *
                         matrix.rotate(target.rotation / 180 * math.pi)
    elseif target.rotation == 270 then
        WIDTH, HEIGHT = HEIGHT, WIDTH
        setup = function()
            gl.translate(0, NATIVE_HEIGHT)
            gl.rotate(270, 0, 0, 1)
        end
        surface2screen = matrix.trans(target.x, target.y + target.height) *
                         matrix.scale(
                             target.width / NATIVE_WIDTH,
                             target.height / NATIVE_HEIGHT
                         ) *
                         matrix.rotate(target.rotation / 180 * math.pi)
    else
        error(string.format("cannot rotate by %d degree", target.rotation))
    end

    local function fit(raw)
        local _, width, height = raw:state()
        local x1, y1, x2, y2 = util.scale_into(WIDTH, HEIGHT, width, height)
        local tx1, ty1 = surface2screen(x1, y1)
        local tx2, ty2 = surface2screen(x2, y2)
        return raw:target(
            math.min(tx1, tx2),
            math.min(ty1, ty2),
            math.max(tx1, tx2),
            math.max(ty1, ty2)
        ):rotate(target.rotation)
    end

    return {
        setup = setup;
        fit = fit;
    }
end

return {
    Screen = Screen;
}
