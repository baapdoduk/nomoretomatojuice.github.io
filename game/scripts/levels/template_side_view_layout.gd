class_name TemplateSideViewLayout
extends RefCounted
## ASCII layout of scenes/levels/_template_side_view.tscn: a walled 60-tile
## floor (row 0 = y 0 px) with one 3-tile practice pit. Copy this file next to a
## copy of the template, register both in level_builder.gd and rebuild.
## Legend: CellarTiles.paint_ascii.

const MAP_TOP := -14

const WORLD_MAP: PackedStringArray = [
	"##                                                        ##",
	"##                                                        ##",
	"##                                                        ##",
	"##                                                        ##",
	"##                                                        ##",
	"##                                                        ##",
	"##                                                        ##",
	"##                                                        ##",
	"##                                                        ##",
	"##                                                        ##",
	"##                                                        ##",
	"##                                                        ##",
	"##                                                        ##",
	"##                                                        ##",
	"########################   #################################",
	"########################   #################################",
	"########################   #################################",
	"########################   #################################",
	"########################   #################################",
	"########################   #################################",
]
const DECO_MAP: PackedStringArray = [
	"",
	"",
	"",
	"",
	"",
	"",
	"",
	"",
	"            w",
	"",
	"",
	"",
	"",
	"    kj                                              r",
]
