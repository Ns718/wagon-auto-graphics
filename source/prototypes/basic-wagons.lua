require "libs.all"
require "libs.prototypes.all"

-- 0 = no option
-- +1 = 4 sheet of graphics instead of 1 (hd resolution)
-- +2 = fluid-wagon
local wagons = {
	["coal"]=0, ["iron-ore"]=0, ["copper-ore"]=0, ["wood"]=0, ["stone"]=0, ["steel-plate"]=0, ["stone-brick"]=1, 
	["closed"]=0, ["stuff"]=1, 
	["plate"]=0,
	["petroleum-gas"]=3, ["water"]=3, ["crude-oil"]=3, ["heavy-oil"]=2, ["light-oil"]=2, ["sulfuric-acid"]=3
}

for name, options in pairs(wagons) do
	local copy = (options % 4 >= 2) and "fluid-wagon" or "cargo-wagon"
	local wagon = table.deepcopy(data.raw[copy][copy])
	local pic = {
		priority = "very-low",
		width = 256,
		height = 256,
		back_equals_front = true,
		direction_count = 64,
		filename = "__wagonAutoGraphics__/graphics/wagons/"..name.."_sheet.png",      
		line_length = 8,
		lines_per_file = 8,
		shift = {0.42, -1.125}
	}
	if options % 2 == 1 then
		pic = {
			priority = "very-low",
			width = 512,
			height = 512,
			scale = 0.5,
			back_equals_front = true,
			direction_count = 64,
			filenames = {
				"__wagonAutoGraphics__/graphics/wagons/"..name.."_sheet_0.png",
				"__wagonAutoGraphics__/graphics/wagons/"..name.."_sheet_1.png",
				"__wagonAutoGraphics__/graphics/wagons/"..name.."_sheet_2.png",
				"__wagonAutoGraphics__/graphics/wagons/"..name.."_sheet_3.png"
			},
			line_length = 4,
			lines_per_file = 4,
			shift = {0, -1.125}
		}
	end
	overwriteContent(wagon, {
		name = "wag-"..name.."-wagon",
		order = "zzz",
		icon = "__wagonAutoGraphics__/graphics/wagons/"..name.."_icon.png",icon_size = 32,
		pictures = pic,
	})
	wagon.vertical_doors = nil
	wagon.horizontal_doors = nil
	data:extend{wagon}
end
