{
	"patcher" : 	{
		"fileversion" : 1,
		"appversion" : 		{
			"major" : 9,
			"minor" : 0,
			"revision" : 9,
			"architecture" : "x64",
			"modernui" : 1
		}
,
		"classnamespace" : "box",
		"rect" : [ 103.0, 145.0, 1155.0, 785.0 ],
		"gridsize" : [ 15.0, 15.0 ],
		"boxes" : [ 			{
				"box" : 				{
					"id" : "obj-29",
					"maxclass" : "comment",
					"numinlets" : 1,
					"numoutlets" : 0,
					"patching_rect" : [ 395.5, 203.0, 104.0, 20.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 45.5, 170.0, 104.0, 20.0 ],
					"text" : "pebble 0"
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-28",
					"maxclass" : "comment",
					"numinlets" : 1,
					"numoutlets" : 0,
					"patching_rect" : [ 30.0, 9.0, 245.0, 20.0 ],
					"text" : "pitch           roll             yaw"
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-27",
					"linecount" : 2,
					"maxclass" : "comment",
					"numinlets" : 1,
					"numoutlets" : 0,
					"patching_rect" : [ 245.0, 77.0, 104.0, 33.0 ],
					"text" : "convert to degrees"
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-26",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 151.0, 145.0, 145.0, 22.0 ],
					"text" : "expr ($f1 * 180) / 3.14159"
				}

			}
, 			{
				"box" : 				{
					"format" : 6,
					"id" : "obj-25",
					"maxclass" : "flonum",
					"maximum" : 2.0,
					"minimum" : -1.0,
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "bang" ],
					"parameter_enable" : 1,
					"patching_rect" : [ 151.0, 37.0, 50.0, 22.0 ],
					"saved_attribute_attributes" : 					{
						"valueof" : 						{
							"parameter_invisible" : 1,
							"parameter_longname" : "y0",
							"parameter_mmax" : 2.0,
							"parameter_mmin" : -1.0,
							"parameter_modmode" : 3,
							"parameter_shortname" : "y0",
							"parameter_type" : 0
						}

					}
,
					"varname" : "number[2]"
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-24",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 91.0, 112.0, 145.0, 22.0 ],
					"text" : "expr ($f1 * 180) / 3.14159"
				}

			}
, 			{
				"box" : 				{
					"format" : 6,
					"id" : "obj-23",
					"maxclass" : "flonum",
					"maximum" : 2.0,
					"minimum" : -1.0,
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "bang" ],
					"parameter_enable" : 1,
					"patching_rect" : [ 91.0, 37.0, 50.0, 22.0 ],
					"saved_attribute_attributes" : 					{
						"valueof" : 						{
							"parameter_invisible" : 1,
							"parameter_longname" : "r0",
							"parameter_mmax" : 2.0,
							"parameter_mmin" : -1.0,
							"parameter_modmode" : 3,
							"parameter_shortname" : "r0",
							"parameter_type" : 0
						}

					}
,
					"varname" : "number[1]"
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-22",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 30.0, 74.0, 145.0, 22.0 ],
					"text" : "expr ($f1 * 180) / 3.14159"
				}

			}
, 			{
				"box" : 				{
					"format" : 6,
					"id" : "obj-19",
					"maxclass" : "flonum",
					"maximum" : 2.0,
					"minimum" : -1.0,
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "bang" ],
					"parameter_enable" : 1,
					"patching_rect" : [ 30.0, 37.0, 50.0, 22.0 ],
					"saved_attribute_attributes" : 					{
						"valueof" : 						{
							"parameter_invisible" : 1,
							"parameter_longname" : "p0",
							"parameter_mmax" : 2.0,
							"parameter_mmin" : -1.0,
							"parameter_modmode" : 3,
							"parameter_shortname" : "p0",
							"parameter_type" : 0
						}

					}
,
					"varname" : "number"
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-13",
					"maxclass" : "message",
					"numinlets" : 2,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 822.0, 674.0, 50.0, 22.0 ]
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-8",
					"maxclass" : "number",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "bang" ],
					"parameter_enable" : 0,
					"patching_rect" : [ 946.0, 674.0, 50.0, 22.0 ]
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-7",
					"maxclass" : "number",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "bang" ],
					"parameter_enable" : 0,
					"patching_rect" : [ 886.0, 674.0, 50.0, 22.0 ]
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-2",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 3,
					"outlettype" : [ "", "int", "float" ],
					"patching_rect" : [ 826.0, 595.0, 85.0, 22.0 ],
					"text" : "unpack sym i f"
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-6",
					"maxclass" : "message",
					"numinlets" : 2,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 646.0, 619.0, 175.0, 22.0 ],
					"text" : "/pebbleraw/y0 0.750934"
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-5",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 802.0, 546.0, 104.0, 22.0 ],
					"text" : "udpreceive 30338"
				}

			}
, 			{
				"box" : 				{
					"filename" : "none",
					"id" : "obj-123",
					"maxclass" : "v8ui",
					"numinlets" : 1,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"parameter_enable" : 0,
					"patching_rect" : [ 380.0, 59.0, 135.0, 135.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 30.0, 30.0, 135.0, 135.0 ],
					"textfile" : 					{
						"text" : "mgraphics.init();\nmgraphics.relative_coords = 0;\nmgraphics.autofill = 0;\n\nlet yaw = 0;\nlet pitch = 0;\nlet roll = 0;\n\n// Cube size and scale factor\nconst cubeSize = 40; // pixels (half side length)\nconst cx = 64;      // center x (fixed for 512x512)\nconst cy = 64;      // center y\n\n// 8 cube vertices centered around origin\nconst baseVertices = [\n  [-1, -1, -1],\n  [ 1, -1, -1],\n  [ 1,  1, -1],\n  [-1,  1, -1],\n  [-1, -1,  1],\n  [ 1, -1,  1],\n  [ 1,  1,  1],\n  [-1,  1,  1],\n];\n\n// Edge list\nconst edges = [\n  [0,1],[1,2],[2,3],[3,0], // back\n  [4,5],[5,6],[6,7],[7,4], // front\n  [0,4],[1,5],[2,6],[3,7], // connections\n];\n\nfunction list(y, p, r) {\n  yaw = y;\n  pitch = p;\n  roll = r;\n  mgraphics.redraw();\n}\n\nfunction paint() {\n  mgraphics.set_source_rgba(0, 0, 0, 1);\n  mgraphics.rectangle(0, 0, box.rect[2], box.rect[3]);\n  mgraphics.fill();\n\n  const rotated = baseVertices.map(v => rotate(v));\n\n  mgraphics.set_source_rgba(1, 1, 1, 1);\n  mgraphics.set_line_width(3);\n  for (let [i, j] of edges) {\n    const [x1, y1] = project(rotated[i]);\n    const [x2, y2] = project(rotated[j]);\n    mgraphics.move_to(x1, y1);\n    mgraphics.line_to(x2, y2);\n  }\n  mgraphics.stroke();\n}\n\nfunction project([x, y, z]) {\n  return [cx + x * cubeSize, cy - y * cubeSize];\n}\n\nfunction rotate([x, y, z]) {\n  x *= 1; y *= 1; z *= 1;\n\n  const toRad = deg => deg * Math.PI / 180;\n  const sin = Math.sin, cos = Math.cos;\n\n  const p = toRad(pitch);\n  const y_ = toRad(yaw);\n  const r = toRad(roll);\n\n  // Pitch (X axis)\n  let y1 = y * cos(p) - z * sin(p);\n  let z1 = y * sin(p) + z * cos(p);\n  y = y1; z = z1;\n\n  // Yaw (Y axis)\n  let x1 = x * cos(y_) + z * sin(y_);\n  z1 = -x * sin(y_) + z * cos(y_);\n  x = x1; z = z1;\n\n  // Roll (Z axis)\n  x1 = x * cos(r) - y * sin(r);\n  y1 = x * sin(r) + y * cos(r);\n  x = x1; y = y1;\n\n  return [x, y, z];\n}\n",
						"filename" : "none",
						"flags" : 0,
						"embed" : 1,
						"autowatch" : 1
					}

				}

			}
, 			{
				"box" : 				{
					"id" : "obj-121",
					"maxclass" : "newobj",
					"numinlets" : 3,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 226.0, 223.0, 54.0, 22.0 ],
					"text" : "pack f f f"
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-119",
					"linecount" : 2,
					"maxclass" : "comment",
					"numinlets" : 1,
					"numoutlets" : 0,
					"patching_rect" : [ 226.0, 178.0, 104.0, 33.0 ],
					"text" : "filtered and fused \nyaw, pitch, roll"
				}

			}
, 			{
				"box" : 				{
					"id" : "obj-118",
					"maxclass" : "comment",
					"numinlets" : 1,
					"numoutlets" : 0,
					"patching_rect" : [ 30.0, 435.0, 119.0, 20.0 ],
					"text" : "raw accel / gyro data"
				}

			}
, 			{
				"box" : 				{
					"bgcolor" : [ 0.0, 0.0, 0.0, 1.0 ],
					"id" : "obj-110",
					"maxclass" : "multislider",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "" ],
					"parameter_enable" : 0,
					"patching_rect" : [ 151.0, 268.0, 45.0, 150.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 137.0, 208.0, 45.0, 150.0 ],
					"setminmax" : [ 0.0, 360.0 ],
					"setstyle" : 3,
					"signed" : 1,
					"slidercolor" : [ 1.0, 1.0, 1.0, 1.0 ]
				}

			}
, 			{
				"box" : 				{
					"bgcolor" : [ 0.0, 0.0, 0.0, 1.0 ],
					"id" : "obj-109",
					"maxclass" : "multislider",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "" ],
					"parameter_enable" : 0,
					"patching_rect" : [ 91.0, 268.0, 45.0, 150.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 77.0, 208.0, 45.0, 150.0 ],
					"setminmax" : [ -180.0, 180.0 ],
					"setstyle" : 3,
					"signed" : 1,
					"slidercolor" : [ 1.0, 1.0, 1.0, 1.0 ]
				}

			}
, 			{
				"box" : 				{
					"bgcolor" : [ 0.0, 0.0, 0.0, 1.0 ],
					"id" : "obj-108",
					"maxclass" : "multislider",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "" ],
					"parameter_enable" : 0,
					"patching_rect" : [ 31.0, 268.0, 45.0, 150.0 ],
					"presentation" : 1,
					"presentation_rect" : [ 17.0, 208.0, 45.0, 150.0 ],
					"setminmax" : [ -90.0, 90.0 ],
					"setstyle" : 3,
					"signed" : 1,
					"slidercolor" : [ 1.0, 1.0, 1.0, 1.0 ]
				}

			}
, 			{
				"box" : 				{
					"format" : 6,
					"id" : "obj-83",
					"maxclass" : "flonum",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "bang" ],
					"parameter_enable" : 0,
					"patching_rect" : [ 151.0, 223.0, 50.0, 22.0 ]
				}

			}
, 			{
				"box" : 				{
					"format" : 6,
					"id" : "obj-85",
					"maxclass" : "flonum",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "bang" ],
					"parameter_enable" : 0,
					"patching_rect" : [ 91.0, 223.0, 50.0, 22.0 ]
				}

			}
, 			{
				"box" : 				{
					"format" : 6,
					"id" : "obj-87",
					"maxclass" : "flonum",
					"numinlets" : 1,
					"numoutlets" : 2,
					"outlettype" : [ "", "bang" ],
					"parameter_enable" : 0,
					"patching_rect" : [ 31.0, 223.0, 50.0, 22.0 ]
				}

			}
 ],
		"lines" : [ 			{
				"patchline" : 				{
					"destination" : [ "obj-123", 0 ],
					"midpoints" : [ 235.5, 437.0, 709.92578125, 437.0, 709.92578125, 200.0, 389.5, 200.0 ],
					"source" : [ "obj-121", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-22", 0 ],
					"source" : [ "obj-19", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-13", 0 ],
					"source" : [ "obj-2", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-7", 0 ],
					"source" : [ "obj-2", 1 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-8", 0 ],
					"source" : [ "obj-2", 2 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-87", 0 ],
					"source" : [ "obj-22", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-24", 0 ],
					"source" : [ "obj-23", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-85", 0 ],
					"source" : [ "obj-24", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-26", 0 ],
					"source" : [ "obj-25", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-83", 0 ],
					"source" : [ "obj-26", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-6", 1 ],
					"order" : 0,
					"source" : [ "obj-5", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-6", 0 ],
					"order" : 1,
					"source" : [ "obj-5", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-110", 0 ],
					"order" : 1,
					"source" : [ "obj-83", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-121", 2 ],
					"order" : 0,
					"source" : [ "obj-83", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-109", 0 ],
					"order" : 1,
					"source" : [ "obj-85", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-121", 1 ],
					"order" : 0,
					"source" : [ "obj-85", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-108", 0 ],
					"order" : 1,
					"source" : [ "obj-87", 0 ]
				}

			}
, 			{
				"patchline" : 				{
					"destination" : [ "obj-121", 0 ],
					"order" : 0,
					"source" : [ "obj-87", 0 ]
				}

			}
 ],
		"parameters" : 		{
			"obj-19" : [ "p0", "p0", 0 ],
			"obj-23" : [ "r0", "r0", 0 ],
			"obj-25" : [ "y0", "y0", 0 ],
			"inherited_shortname" : 1
		}
,
		"dependency_cache" : [ 			{
				"name" : "v8ui_default.js",
				"bootpath" : "C74:/jsui",
				"type" : "TEXT",
				"implicit" : 1
			}
 ],
		"autosave" : 0,
		"toolbaradditions" : [ "Data Knot" ]
	}

}
