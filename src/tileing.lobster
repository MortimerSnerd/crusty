// Tiled texture implementations that have some common
// functions for access.
import vec
import logging

// A texture that is divided evenly into a grid of quads,
// with each quad being indexed by an int.  Grids are numbered
// in column-major order. Ie:
//     0 1 2
//     3 4 5
// TODO for testing purposes now - sprites need borders to avoid bleeding on min/mag.
class GridTiledTexture:
   texture: resource
   gridDims: xy_i  // Dimensions in quads.
   tileTxSz: xy_f  // dimensions of quad in texture coordinates.


// Calls f with the topLeft, topRight, bottomRight and bottomLeft texture
// coordinates for entry #`i`.
def withTexCoords(lu:: GridTiledTexture, i: int, f):
   // The idea here is it's cheap to calc the coords when needed
   // rather than just keeping array of points to lookup all the time.
   let tlx = i % gridDims.x
   let tly = i / gridDims.x
   let tl = xy{float(tlx) * tileTxSz.x, float(tly) * tileTxSz.y}
   f(tl, tl + xy{tileTxSz.x, 0}, tl + tileTxSz, tl + xy{0.0, tileTxSz.y})

// Creates a tiled texture where the texture is evently divided up into
// a grid of tiles, where each tile's size is `tileDims`
def mkGridTiledTexture(txt: resource, tileDims: xy_i):
   let tx_sz = gl_texture_size(txt)

   assert tileDims.x > 0 and tileDims.y > 0
   assert tx_sz.x > tileDims.x and tx_sz.y > tileDims.y

   if tx_sz.x % tileDims.x != 0 or tx_sz.y % tileDims.y != 0:
      warn(): "Texture size not evenly divided by grid size: " + 
              string(tx_sz) + " vs " + string(tileDims)

   let nx = tx_sz.x / tileDims.x 
   let ny = tx_sz.y / tileDims.y
   let tileTxSz = xy{float(tileDims.x) / tx_sz.x, float(tileDims.y) / tx_sz.y}

   return GridTiledTexture{texture: txt, 
                           gridDims: xy{nx, ny}, 
                           tileTxSz: tileTxSz}

// Adds indexed geometry to vertices + indices + tc for a axis aligned quad.
def addTileQuad(tiledTexture, tileIdx: int, topLeft: xyz_f, dims: xy_f, 
                vertices: [xyz_f], indices: [int], tc: [xy_f]):
   let basei = length(vertices)

   push(vertices, topLeft)
   push(vertices, xyz{topLeft.x + dims.x, topLeft.y, topLeft.z})
   push(vertices, xyz{topLeft.x + dims.x, topLeft.y + dims.y, topLeft.z})
   push(vertices, xyz{topLeft.x, topLeft.y + dims.y, topLeft.z})
   
   withTexCoords(tiledTexture, tileIdx) tc0, tc1, tc2, tc3:
      push(tc, tc0)
      push(tc, tc1)
      push(tc, tc2)
      push(tc, tc3)

   push(indices, basei + 0)
   push(indices, basei + 1)
   push(indices, basei + 2)

   push(indices, basei + 0)
   push(indices, basei + 2)
   push(indices, basei + 3)

// Dynamic sprite rendering - ugly, but does the job for the moment.
// Can draw 500 sprites on a slow system with mediocre video card
// without dropping frame rate, so probably not anything to be concerned
// about yet.  The alternative is batching the draws and creating a new 
// mesh for every frame, which doesn't sound so great either.

// Renders a sprite.  Assumes the texture state has already be set.
def renderSprite(tiledTexture, tileIdx: int, center: xyz_f, dims: xy_f):
   //TODO doing this marlarky with inverting the height to make gl_rect_tc_col()
   // work with gl_ortho3d way of making a y down axis.  Bug, or a misunderstanding?
   let rdim = xy{dims.x, -dims.y}
   let hdim = xyz{rdim.x*0.5, rdim.y*0.5, 0.0}
   gl_translate(center-hdim):
     withTexCoords(tiledTexture, tileIdx) t0, t1, t2, t3:
        gl_rect_tc_col(rdim, t0, t2-t0, [])      

// Renders a sprite.  Assumes the texture state has already be set.
def renderSprite(tiledTexture, tileIdx: int, center: xyz_f, dims: xy_f, angle: xy_f):
   //TODO doing this marlarky with inverting the height to make gl_rect_tc_col()
   // work with gl_ortho3d way of making a y down axis. Bug, or a misunderstanding?
   let rdim = xy{dims.x, -dims.y}
   let hdim = xyz{rdim.x*0.5, rdim.y*0.5, 0.0}
   gl_translate(center):
     gl_rotate_z(angle):
        withTexCoords(tiledTexture, tileIdx) t0, t1, t2, t3:
           gl_translate(-hdim):
              gl_rect_tc_col(rdim, t0, t2-t0, [])      
