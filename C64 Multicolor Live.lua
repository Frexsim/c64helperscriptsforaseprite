local function checkPrerequesities()
    local sprite = app.activeSprite
    if (not sprite) then
        app.alert("There is no active sprite!")

        return false
    end

    local spriteCellWidth = sprite.width / 4
    local spriteCellHeight = sprite.height / 8
    if spriteCellWidth - math.floor(spriteCellWidth) ~= 0 or spriteCellHeight - math.floor(spriteCellHeight) ~= 0 then
        app.alert("Invalid sprite dimensions, consider changing dimensions to: " ..
            math.floor(spriteCellWidth) * 4 ..
            "x" ..
            math.floor(spriteCellHeight) * 8 ..
            " or " .. math.ceil(spriteCellWidth) * 4 .. "x" .. math.ceil(spriteCellHeight) * 8 .. "!")

        return false
    end


    if (sprite.colorMode ~= ColorMode.INDEXED) then
        app.alert("The sprite should use indexed color mode!")

        return false
    end

    return true
end

local function tableCount(table)
    local count = 0
    for i in pairs(table) do
        count = count + 1
    end

    return count
end

local function getCells(image)
    local cells = {}
    local cellIndex = 0
    for cellY = 0, image.height / 8 - 1 do
        for cellX = 0, image.width / 4 - 1 do
            local cellPixels = {}
            local pixelIndex = 0
            for pixelY = 0, 7 do
                for pixelX = 0, 3 do
                    local color = image:getPixel(cellX * 4 + pixelX, cellY * 8 + pixelY)
                    cellPixels[pixelIndex] = {
                        position = {
                            x = pixelX,
                            y = pixelY,
                        },
                        color = color,
                    }
                    pixelIndex = pixelIndex + 1
                end
            end
            cells[cellIndex] = {
                position = {
                    x = cellX,
                    y = cellY,
                },
                pixels = cellPixels,
            }
            cellIndex = cellIndex + 1
        end
    end

    return cells
end

local function getDifferences(prevCells, newCells)
    local differences = {}
    local differenceIndex = 0
    for prevCellIndex, prevCell in pairs(prevCells) do
        for prevPixelIndex, prevPixel in pairs(prevCell.pixels) do
            if (newCells[prevCellIndex].pixels[prevPixelIndex].color ~= prevPixel.color) then
                differences[differenceIndex] = {
                    prevCell = prevCell,
                    newCell = newCells[prevCellIndex],

                    prevPixel = prevPixel,
                    newPixel = newCells[prevCellIndex].pixels[prevPixelIndex],
                }
                differenceIndex = differenceIndex + 1
            end
        end
    end

    return differences
end

local function computeDifferences(differences, image, backgroundColor)
    app.transaction(function()
        for differenceIndex, difference in pairs(differences) do
            local colors = {}
            for pixelIndex, pixel in pairs(difference.newCell.pixels) do
                if (not colors[pixel.color]) then
                    colors[pixel.color] = pixel.color
                end
            end

            if (tableCount(colors) > 3 and not colors[backgroundColor] or tableCount(colors) > 4 and colors[backgroundColor]) then
                if (difference.prevPixel.color ~= backgroundColor) then
                    for pixelIndex, pixel in pairs(difference.newCell.pixels) do
                        if (pixel.color == difference.prevPixel.color) then
                            image:putPixel(difference.newCell.position.x * 4 + pixel.position.x,
                                difference.newCell.position.y * 8 + pixel.position.y, difference.newPixel.color)
                        end
                    end
                else
                    image:putPixel(difference.newCell.position.x * 4 + difference.newPixel.position.x,
                        difference.newCell.position.y * 8 + difference.newPixel.position.y, backgroundColor)
                end
            end
        end

        app.activeLayer:cel(app.activeFrame).image = image
    end)
end

local function replaceBackgroundColor(colorToReplace, colorToReplaceWith)
    local image = Image(app.activeSprite.spec)
    image:drawSprite(app.activeSprite, app.activeFrame)
    for pixelY = 0, image.height - 1 do
        for pixelX = 0, image.width - 1 do
            local pixelColor = image:getPixel(pixelX, pixelY)
            if (pixelColor == colorToReplace) then
                image:drawPixel(pixelX, pixelY, colorToReplaceWith)
            end
        end
    end

    app.activeLayer:cel(app.activeFrame).image = image
    app.refresh()
end

local canRun = checkPrerequesities()
if (canRun) then
    local sprite = app.activeSprite

    local prevImage = Image(sprite.spec)
    prevImage:drawSprite(sprite, app.activeFrame)
    local prevCells = getCells(prevImage)

    local prevBackgroundColor = 0

    local dialog = Dialog("C64 Multicolor Live")
    dialog
        :color({ id = "backgroundColor", label = "Background Color", color = prevBackgroundColor, onchange = function() replaceBackgroundColor(prevBackgroundColor, dialog.data.backgroundColor.index) prevBackgroundColor = dialog.data.backgroundColor.index end})
        :show({ wait = false })

    sprite.events:on("change", function()
        local newImage = Image(sprite.spec)
        newImage:drawSprite(sprite, app.activeFrame)
        local newCells = getCells(newImage)

        local differences = getDifferences(prevCells, newCells)

        computeDifferences(differences, newImage, dialog.data.backgroundColor.index)
        local newCells = getCells(newImage)
        prevCells = newCells

        app.refresh()
    end)
end
