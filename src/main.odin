package marching_cubes

import "core:math/rand"

// Create a random cube from a mask of vertex values
// bits of 0 will be below isolevel
// bits of 1 will be above isolevel
cube_from_mask :: proc(m: u8, allocator := context.temp_allocator) -> []u8 {
	cube := make([]u8, 8, allocator)
	for i in 0 ..= 7 {
		cube[i] = u8(rand.uint32() % 8)
		if m & (1 << u8(i)) > 0 {
			cube[i] += 8
		}
	}
	return cube[:]
}


// Determine the configuration based on the cube values
determine_configuration :: proc(cube: []u8) -> u8 {
	configuration := u8(0)
	for v, i in cube {
		if v >= 8 {
			configuration |= 1 << u8(i)
		}
	}
	return configuration
}

vertex_interpolate_midpoint :: proc(edge: u8) -> [3]f32 {
	// Edges follow ascending path 0 -> 1, 1 -> 2...
	// Vertical edges are last following the same order
	// So 0 -> 4, 1 -> 5...
	//
	//    4+-------+5     +---4---+     +-------+ 
	//    /|      /|     7|      5|    /|      /|
	//   / |     / |    / |     / |   / 8     / 9
	// 7+--|----+6 |   +--|6---+  |  +--|----+  |
	//  |  |    |  |   |  |    |  |  |  |    |  |
	//  | 0+-------+1  |  +--0----+  11 +-------+
	//  | /     | /    | 3     | 1   | /     | /
	//  |/      |/     |/      |/    |/      |/
	// 3+-------+2     +---2---+     +-------+

	a, b: [3]f32
	switch edge {
	case 0:
		b.x = 1
	case 1:
		a.x = 1
		b.x = 1
		b.z = 1
	case 2:
		a.x = 1
		a.z = 1
		b.z = 1
	case 3:
		b.z = 1
	case 4:
		a.y = 1
		b.y = 1
		b.x = 1
	case 5:
		a.y = 1
		b.y = 1
		a.x = 1
		b.x = 1
		b.z = 1
	case 6:
		a.y = 1
		b.y = 1
		a.x = 1
		a.z = 1
		b.z = 1
	case 7:
		a.y = 1
		b.y = 1
		b.z = 1
	case 8:
		b.y = 1
	case 9:
		b.y = 1
		a.x = 1
		b.x = 1
	case 10:
		b.y = 1
		a.x = 1
		b.x = 1
		a.z = 1
		b.z = 1
	case 11:
		b.y = 1
		a.z = 1
		b.z = 1
	}

	// TODO: Non-midpoint
	return a + (b - a) / 2
}

// Given 8 scalar field vaules as a cube, generate the triangles
generate_triangles :: proc(
	cube: []u8,
	offset: [3]f32,
	scale: f32,
	interpolate := vertex_interpolate_midpoint,
	allocator := context.allocator,
) -> [][3][3]f32 {
	triangles := make([dynamic][3][3]f32, allocator)
	configuration := determine_configuration(cube)

	if configuration != 0 && configuration != 255 {
		vertices := make([][3]f32, 12, allocator)

		// TODO: Figure out how to skip edges only using required ones
		for edge: u8 = 0; edge < 12; edge += 1 {
			vertices[edge] = interpolate(edge) * scale + offset
		}

		for indices in triangle_table[configuration] {
			append(
				&triangles,
				[3][3]f32{vertices[indices.x], vertices[indices.y], vertices[indices.z]},
			)
		}
	}
	return triangles[:]
}

cube_corner_pos_from_index :: proc(index: int) -> [3]f32 {
	base_positions := [][3]f32{{}, {1, 0, 0}, {1, 0, 1}, {0, 0, 1}}

	top_offset := [3]f32{0, 1, 0}

	if index < 4 {
		return base_positions[index]
	} else {
		return base_positions[index - 4] + top_offset
	}
}
